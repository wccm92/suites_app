defmodule MsSuitesApp.Domain.RegisterSeasonTicketHolderUsecase do
  @moduledoc """
  Registro de un abonado (season ticket holder) en una suite.

  Contrato API POST `/suites_app/register_season_ticket_holder`.
  body_request:

      %{"id_suite" => "E001", "id_season_ticket_holder" => "1047451430"}

  En caso exitoso basta con responder http 200 y que `body.detail` no
  contenga ningún valor "error".

  Flujo de validación antes de registrar (en este orden):
    1. cédula en blacklist                         -> code "10" (:black_list)
    2. abonados:
         * ya es abonado en la MISMA suite          -> éxito idempotente
         * ya es abonado en OTRA suite              -> code "11" (incluye la suite)
    3. visitantexevento:
         * no está registrada                       -> se registrará como invitado
         * ya está registrada en la MISMA suite     -> se permite (no se reinserta
                                                       en visitantexevento)
         * ya está registrada en OTRA suite         -> code "09" (incluye cédula y suite)
    4. registro (en una única transacción), según el caso:
         * visitante            (tabla `visitante`)
         * invitado del evento  (tabla `visitantexevento`, solo si no estaba ya
                                 registrado en esta suite)
         * abonado              (tabla `abonados`)
  """

  require Logger

  alias MsSuitesApp.Domain.LoginUsecase
  alias MsSuitesApp.Infrastructure.Adapters.Repo
  alias MsSuitesApp.Infrastructure.Adapters.SuitesQueryAdapter
  alias MsSuitesApp.Infrastructure.Adapters.AbonadosQueryAdapter

  def handle_register_season_ticket_holder(id_suite, id_season_ticket_holder, token)
      when is_binary(id_suite) do
    documento = normalize_doc(id_season_ticket_holder)

    with {:ok, event_user} <-
           LoginUsecase.validate_event_and_session(token, "profile_validation_enable"),
         :ok <- validate_not_blacklisted(documento),
         :ok <- validate_suite_membership(documento, id_suite),
         {:ok, guest_status} <- validate_guest_membership(event_user.id, id_suite, documento),
         :ok <- register(event_user.id, id_suite, documento, guest_status) do
      {:ok, success_response()}
    else
      :already_registered ->
        {:ok, success_response()}

      {:error, _} = error ->
        error
    end
  end

  def handle_register_season_ticket_holder(_id_suite, _id_season_ticket_holder, _token),
      do: {:error, :invalid_body}

  # Reutiliza la blacklist ya existente en el proyecto (code "10").
  defp validate_not_blacklisted(documento) do
    if SuitesQueryAdapter.validate_blacklisted(documento) do
      {:error, :black_list}
    else
      :ok
    end
  end

  # nil            -> no está abonado en ninguna suite   -> :ok
  # misma suite    -> ya está abonado aquí (idempotente) -> :already_registered
  # otra suite     -> code "11" (con la suite en la que está abonado)
  defp validate_suite_membership(documento, id_suite) do
    case AbonadosQueryAdapter.get_suite_of_abonado(documento) do
      nil -> :ok
      ^id_suite -> :already_registered
      other_suite -> {:error, {:abonado_already_in_other_suite, other_suite}}
    end
  end

  # :not_found         -> no es invitado del evento           -> {:ok, :not_guest}
  # misma suite        -> ya es invitado de esta suite        -> {:ok, :guest_same_suite}
  #                       (se permite, no se reinserta en visitantexevento)
  # otra suite         -> ya es invitado de otra suite        -> code "09"
  defp validate_guest_membership(id_evento, id_suite, documento) do
    case SuitesQueryAdapter.validate_guess_in_event(id_evento, documento) do
      :not_found ->
        {:ok, :not_guest}

      {:ok, ^id_suite} ->
        {:ok, :guest_same_suite}

      {:ok, other_suite} ->
        {:error,
          {:visitor_already_registered_in_event,
            %{id_suite: other_suite, id_visitante: documento}}}
    end
  end

  # Registra, en una única transacción, la cédula como visitante, como
  # invitado del evento (solo si aún no lo era en esta suite) y como abonado.
  defp register(id_evento, id_suite, documento, guest_status) do
    Repo.transaction(fn ->
      with :ok <- SuitesQueryAdapter.ensure_visitante_exists(documento),
           {:ok, _} <- maybe_register_guest(guest_status, id_evento, id_suite, documento),
           {:ok, _} <-
             AbonadosQueryAdapter.register_season_ticket_holder(documento, id_suite) do
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

  # Ya era invitado de esta suite: no se reinserta en visitantexevento.
  defp maybe_register_guest(:guest_same_suite, _id_evento, _id_suite, _documento),
       do: {:ok, :already_guest}

  # No era invitado: se registra en visitantexevento siguiendo el mismo patrón
  # que do_register_one de register_guest_usecase.
  defp maybe_register_guest(:not_guest, id_evento, id_suite, documento) do
    case SuitesQueryAdapter.register_guest_in_suite(id_evento, id_suite, documento) do
      {:ok, _} = ok ->
        ok

      other ->
        {:error, {:guest_register_failed, other}}
    end
  end

  defp success_response do
    %{title: "success", detail: "Abonado registrado correctamente"}
  end

  defp normalize_doc(doc), do: doc |> to_string() |> String.trim()
end