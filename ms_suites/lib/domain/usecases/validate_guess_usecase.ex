defmodule MsSuitesApp.Domain.ValidateGuestUsecase do
  import Ecto.Query, warn: false


  alias MsSuitesApp.Domain.LoginUsecase
  alias MsSuitesApp.Infrastructure.Adapters.SuitesQueryAdapter
  require Logger

  @doc """
  Devuelve TODAS las suites (equivalente a: SELECT * FROM suites).
  """

  def handle_validate_guess(id_suite, id_visitante, token) do
    with {:ok, event_user_info} <- LoginUsecase.validate_event_and_session(token),
         {:ok, true} <- validate_blacklist(id_visitante),
         {:ok, true} <- validate_guess(id_visitante, event_user_info),
         {:ok, body} <- build_body(id_visitante) do
      {:ok, body}
    else
      {:error, reason} = error ->
        Logger.error("Error en handle_validate_guess: #{inspect(reason)}")
        error
    end
  end

  defp validate_blacklist(id_visitante) do
    Logger.debug("Consultando invitado en la lista negra")
    {:ok, true}
  end


  defp validate_guess(id_visitante, event_user_info) do
    Logger.debug("Validando si visitante ya está registrado en el evento")

    case SuitesQueryAdapter.validate_guess_in_event(event_user_info.id_evento, id_visitante) do
      :not_found ->
        {:ok, true}

      {:ok, registered_suite_id} ->
        {:error, {:visitor_already_registered_in_event, %{id_suite: registered_suite_id}}}
    end
  end

  defp build_body(id_visitante) do
    {:ok, %{invitado: id_visitante}}
  end





end
