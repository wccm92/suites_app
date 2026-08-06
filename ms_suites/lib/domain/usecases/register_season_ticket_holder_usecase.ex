defmodule MsSuitesApp.Domain.RegisterSeasonTicketHolderUsecase do
  @moduledoc """
  Registro de un abonado (season ticket holder) en una suite.

  Contrato API POST `/suites_app/register_season_ticket_holder`.
  body_request:

      %{"id_suite" => "E001", "id_season_ticket_holder" => "1047451430"}

  En caso exitoso basta con responder http 200 y que `body.detail` no
  contenga ningún valor "error".

  Flujo de validación antes de registrar (en este orden):
    1. cédula en blacklist                        -> code "10" (:black_list)
    2. ya es abonado en OTRA suite                 -> code "11"
       ya es abonado en la MISMA suite             -> éxito idempotente
    3. ya está inscrita como invitado del evento   -> code "11"
       (visitantexevento)
    4. si no cae en ninguno de los casos previos, se registra en una única
       transacción como:
         * visitante            (tabla `visitante`)
         * invitado del evento  (tabla `visitantexevento`)
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
         :ok <- validate_not_guest(event_user.id, documento),
         :ok <- register(event_user.id, id_suite, documento) do
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
  # otra suite     -> code "11"
  defp validate_suite_membership(documento, id_suite) do
    case AbonadosQueryAdapter.get_suite_of_abonado(documento) do
      nil -> :ok
      ^id_suite -> :already_registered
      _other_suite -> {:error, :abonado_already_in_other_suite}
    end
  end

  # Si la cédula ya está inscrita como invitado del evento (visitantexevento),
  # se considera comprometida en otra suite -> code "11".
  defp validate_not_guest(id_evento, documento) do
    if SuitesQueryAdapter.guest_registered?(id_evento, documento) do
      {:error, :abonado_already_in_other_suite}
    else
      :ok
    end
  end

  # Registra, en una única transacción, la cédula como visitante,
  # como invitado del evento (visitantexevento) y como abonado.
  defp register(id_evento, id_suite, documento) do
    Repo.transaction(fn ->
      with :ok <- SuitesQueryAdapter.ensure_visitante_exists(documento),
           {:ok, _} <- register_guest(id_evento, id_suite, documento),
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

         {:error, :already_registered} ->
           {:error, :abonado_already_in_other_suite}

         {:error, reason} ->
           Logger.error("Error registrando abonado: #{inspect(reason)}")
           {:error, :internal_error}
       end
  end

  # Registro en visitantexevento siguiendo el mismo patrón que
  # do_register_one / already_registered_response de register_guest_usecase.
  defp register_guest(id_evento, id_suite, documento) do
    case SuitesQueryAdapter.register_guest_in_suite(id_evento, id_suite, documento) do
      {:ok, _} = ok ->
        ok

      {:error, {:constraint_error, "visitantexevento_pkey"}} ->
        {:error, :already_registered}

      other ->
        {:error, {:guest_register_failed, other}}
    end
  end

  defp success_response do
    %{title: "success", detail: "Abonado registrado correctamente"}
  end

  defp normalize_doc(doc), do: doc |> to_string() |> String.trim()
end