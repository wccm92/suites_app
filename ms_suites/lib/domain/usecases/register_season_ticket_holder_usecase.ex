defmodule MsSuitesApp.Domain.RegisterSeasonTicketHolderUsecase do
  @moduledoc """
  Registro de un abonado (season ticket holder) en una suite.

  Contrato API POST `/suites_app/register_season_ticket_holder`.
  body_request:

      %{"id_suite" => "E001", "id_season_ticket_holder" => "1047451430"}

  En caso exitoso basta con responder http 200 y que `body.detail` no
  contenga ningún valor "error".

  Validaciones / errores propios:
    * cédula en blacklist        -> code "10" (:black_list)
    * cédula abonada en otra suite -> code "11" (:abonado_already_in_other_suite)
  """

  require Logger

  alias MsSuitesApp.Domain.LoginUsecase
  alias MsSuitesApp.Infrastructure.Adapters.SuitesQueryAdapter
  alias MsSuitesApp.Infrastructure.Adapters.AbonadosQueryAdapter

  def handle_register_season_ticket_holder(id_suite, id_season_ticket_holder, token)
      when is_binary(id_suite) do
    documento = normalize_doc(id_season_ticket_holder)

    with {:ok, _event_user} <-
           LoginUsecase.validate_event_and_session(token, "profile_validation_enable"),
         :ok <- validate_not_blacklisted(documento),
         :ok <- validate_suite_membership(documento, id_suite) do
      register(documento, id_suite)
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

  # nil            -> no está abonado en ninguna suite  -> :ok
  # misma suite    -> ya está abonado aquí (idempotente) -> :already_registered
  # otra suite     -> code "11"
  defp validate_suite_membership(documento, id_suite) do
    case AbonadosQueryAdapter.get_suite_of_abonado(documento) do
      nil -> :ok
      ^id_suite -> :already_registered
      _other_suite -> {:error, :abonado_already_in_other_suite}
    end
  end

  defp register(documento, id_suite) do
    case AbonadosQueryAdapter.register_season_ticket_holder(documento, id_suite) do
      {:ok, _abonado} ->
        {:ok, success_response()}

      {:error, %Ecto.Changeset{} = changeset} ->
        Logger.error("Error registrando abonado: #{inspect(changeset.errors)}")
        {:error, :internal_error}
    end
  end

  defp success_response do
    %{title: "success", detail: "Abonado registrado correctamente"}
  end

  defp normalize_doc(doc), do: doc |> to_string() |> String.trim()
end
