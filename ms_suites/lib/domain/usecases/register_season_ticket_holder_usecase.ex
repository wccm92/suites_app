defmodule MsSuitesApp.Domain.RegisterSeasonTicketHolderUsecase do
  @moduledoc """
  Registro de un abonado (season ticket holder) en una suite y, de forma
  opcional, como visitante del evento actual.

  Contrato API POST `/suites_app/register_season_ticket_holder`.
  body_request:

      %{
        "id_suite" => "E001",
        "id_season_ticket_holder" => "1047451430",
        "registrar_visitante" => true   # opcional, por defecto true
      }

  Respuesta exitosa (http 200). `visitante_evento.estado` informa qué pasó con
  el registro como visitante del evento actual:

      %{
        title: "success",
        detail: "Abonado registrado correctamente",
        visitante_evento: %{
          estado: "registrado" | "ya_registrado" | "sin_cupos" |
                  "registrado_en_otra_suite" | "omitido",
          detail: "...",
          id_suite: "E002"   # solo con "registrado_en_otra_suite"
        }
      }

  Flujo de validación antes de registrar (en este orden):
    1. cédula en blacklist                         -> code "10" (:black_list)
    2. abonados:
         * ya es abonado en la MISMA suite          -> no se reinserta (idempotente)
         * ya es abonado en OTRA suite              -> code "11" (incluye la suite)
    3. límite de abonados (solo abonados nuevos):
         * abonados de la suite >= capacidad        -> code "12"
    4. visitante del evento actual (solo si `registrar_visitante`):
         * ya está registrado en la MISMA suite     -> "ya_registrado"
         * ya está registrado en OTRA suite         -> "registrado_en_otra_suite"
         * la suite no tiene cupos para el evento   -> "sin_cupos"
         * en otro caso                             -> "registrado"
       Ninguno de estos casos impide registrar al abonado: el abonado queda
       inscrito para futuros eventos aunque no entre al evento actual.
    5. registro (en una única transacción):
         * visitante            (tabla `visitante`)
         * invitado del evento  (tabla `visitantexevento`, solo con "registrado")
         * abonado              (tabla `abonados`, solo si es nuevo)
  """

  require Logger

  alias MsSuitesApp.Domain.LoginUsecase
  alias MsSuitesApp.Domain.ValidateSeasonTicketHoldersLimitUsecase
  alias MsSuitesApp.Infrastructure.Adapters.Repo
  alias MsSuitesApp.Infrastructure.Adapters.SuitesQueryAdapter
  alias MsSuitesApp.Infrastructure.Adapters.AbonadosQueryAdapter

  def handle_register_season_ticket_holder(
        id_suite,
        id_season_ticket_holder,
        registrar_visitante,
        token
      )
      when is_binary(id_suite) do
    documento = normalize_doc(id_season_ticket_holder)

    with {:ok, event_user} <-
           LoginUsecase.validate_event_and_session(token, "profile_validation_enable"),
         :ok <- validate_not_blacklisted(documento),
         {:ok, holder_status} <- validate_suite_membership(documento, id_suite),
         :ok <- validate_limit(holder_status, id_suite),
         {:ok, guest_plan} <-
           plan_guest(truthy?(registrar_visitante), event_user.id, id_suite, documento),
         :ok <- register(event_user.id, id_suite, documento, holder_status, guest_plan) do
      {:ok, success_response(holder_status, guest_plan)}
    else
      {:error, _} = error ->
        error
    end
  end

  def handle_register_season_ticket_holder(_id_suite, _id_holder, _registrar_visitante, _token),
      do: {:error, :invalid_body}

  # Reutiliza la blacklist ya existente en el proyecto (code "10").
  defp validate_not_blacklisted(documento) do
    if SuitesQueryAdapter.validate_blacklisted(documento) do
      {:error, :black_list}
    else
      :ok
    end
  end

  # nil            -> no está abonado en ninguna suite   -> {:ok, :new_holder}
  # misma suite    -> ya está abonado aquí (idempotente) -> {:ok, :already_holder}
  # otra suite     -> code "11" (con la suite en la que está abonado)
  defp validate_suite_membership(documento, id_suite) do
    case AbonadosQueryAdapter.get_suite_of_abonado(documento) do
      nil -> {:ok, :new_holder}
      ^id_suite -> {:ok, :already_holder}
      other_suite -> {:error, {:abonado_already_in_other_suite, other_suite}}
    end
  end

  # Un abonado existente no ocupa un cupo nuevo: solo se valida el límite
  # (code "12") cuando el abonado es nuevo.
  defp validate_limit(:already_holder, _id_suite), do: :ok

  defp validate_limit(:new_holder, id_suite) do
    case ValidateSeasonTicketHoldersLimitUsecase.check_limit(id_suite) do
      {:ok, _limit} -> :ok
      {:error, _} = error -> error
    end
  end

  # Decide qué hacer con el registro como visitante del evento actual.
  defp plan_guest(false, _id_evento, _id_suite, _documento), do: {:ok, :omitido}

  defp plan_guest(true, id_evento, id_suite, documento) do
    case SuitesQueryAdapter.validate_guess_in_event(id_evento, documento) do
      {:ok, ^id_suite} ->
        {:ok, :ya_registrado}

      {:ok, other_suite} ->
        {:ok, {:registrado_en_otra_suite, other_suite}}

      :not_found ->
        if cupos_visitantes(id_evento, id_suite) > 0 do
          {:ok, :registrar}
        else
          {:ok, :sin_cupos}
        end
    end
  end

  defp cupos_visitantes(id_evento, id_suite) do
    capacidad = SuitesQueryAdapter.get_suite_capacity(id_suite) || 0
    ValidateSeasonTicketHoldersLimitUsecase.cupos_visitantes_disponibles(id_evento, id_suite, capacidad)
  end

  # Registra, en una única transacción, la cédula como visitante, como
  # invitado del evento (solo con :registrar) y como abonado (solo si es nuevo).
  defp register(id_evento, id_suite, documento, holder_status, guest_plan) do
    Repo.transaction(fn ->
      with :ok <- SuitesQueryAdapter.ensure_visitante_exists(documento),
           {:ok, _} <- maybe_register_guest(guest_plan, id_evento, id_suite, documento),
           {:ok, _} <- maybe_register_holder(holder_status, documento, id_suite) do
        :registered
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
    |> case do
         {:ok, :registered} ->
           :ok

         {:error, reason} ->
           Logger.error("Error registrando abonado: #{inspect(reason)}")
           {:error, :internal_error}
       end
  end

  # Se registra en visitantexevento siguiendo el mismo patrón que
  # register_guest_usecase.
  defp maybe_register_guest(:registrar, id_evento, id_suite, documento) do
    case SuitesQueryAdapter.register_guest_in_suite(id_evento, id_suite, documento) do
      {:ok, _} = ok ->
        ok

      other ->
        {:error, {:guest_register_failed, other}}
    end
  end

  defp maybe_register_guest(_guest_plan, _id_evento, _id_suite, _documento),
       do: {:ok, :skipped}

  defp maybe_register_holder(:new_holder, documento, id_suite),
       do: AbonadosQueryAdapter.register_season_ticket_holder(documento, id_suite)

  defp maybe_register_holder(:already_holder, _documento, _id_suite),
       do: {:ok, :already_holder}

  defp success_response(holder_status, guest_plan) do
    %{
      title: "success",
      detail: holder_detail(holder_status),
      visitante_evento: guest_result(guest_plan)
    }
  end

  defp holder_detail(:new_holder), do: "Abonado registrado correctamente"
  defp holder_detail(:already_holder), do: "El abonado ya se encontraba registrado en esta suite"

  defp guest_result(:registrar),
       do: %{estado: "registrado", detail: "Registrado como visitante del evento actual"}

  defp guest_result(:ya_registrado),
       do: %{estado: "ya_registrado", detail: "Ya era visitante de esta suite en el evento actual"}

  defp guest_result(:sin_cupos),
       do: %{
         estado: "sin_cupos",
         detail:
           "No hay cupos disponibles en la suite para el evento actual, si deseas que quede para el evento actual debes retirar algún visitante"
       }

  defp guest_result({:registrado_en_otra_suite, other_suite}),
       do: %{
         estado: "registrado_en_otra_suite",
         detail: "Ya se encuentra registrado como visitante en la suite " <> other_suite,
         id_suite: other_suite
       }

  defp guest_result(:omitido),
       do: %{estado: "omitido", detail: "No se registró como visitante del evento actual"}

  defp truthy?(value) when value in [false, "false", "0", 0], do: false
  defp truthy?(_value), do: true

  defp normalize_doc(doc), do: doc |> to_string() |> String.trim()
end
