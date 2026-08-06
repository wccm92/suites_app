defmodule MsSuitesApp.Domain.DeleteSeasonTicketHoldersUsecase do
  @moduledoc """
  Eliminación de abonados (season ticket holders) de una suite.

  Contrato API POST `/suites_app/delete_season_ticket_holders`.
  body_request:

      %{"id_suite" => "E001", "season_ticket_holders" => ["1047451430", ...]}

  Respuesta exitosa (http 200). Se mantiene una estructura similar a la del
  API `register_guests` para que el renderizado del front sea análogo:

      %{
        successful_deleted_season_ticket_holders: ["1047451430", ...],
        not_deleted_season_ticket_holders: []
      }
  """

  require Logger

  alias MsSuitesApp.Domain.LoginUsecase
  alias MsSuitesApp.Infrastructure.Adapters.AbonadosQueryAdapter

  def handle_delete_season_ticket_holders(id_suite, season_ticket_holders, token)
      when is_binary(id_suite) and is_list(season_ticket_holders) do
    with {:ok, _event_user} <-
           LoginUsecase.validate_event_and_session(token, "profile_validation_enable"),
         {:ok, response} <- delete_holders(id_suite, season_ticket_holders) do
      {:ok, response}
    else
      {:error, _} = error -> error
    end
  end

  def handle_delete_season_ticket_holders(_id_suite, _season_ticket_holders, _token),
    do: {:error, :invalid_body}

  defp delete_holders(id_suite, season_ticket_holders) do
    ids =
      season_ticket_holders
      |> Enum.map(&normalize_doc/1)
      |> Enum.reject(&is_nil_or_empty?/1)
      |> Enum.uniq()

    deleted = AbonadosQueryAdapter.delete_season_ticket_holders(id_suite, ids)
    not_deleted = ids -- deleted

    {:ok,
     %{
       successful_deleted_season_ticket_holders: deleted,
       not_deleted_season_ticket_holders: not_deleted
     }}
  rescue
    error ->
      Logger.error("Error eliminando abonados en BD: #{Exception.message(error)}")
      {:error, {:db_error, error}}
  end

  defp normalize_doc(doc), do: doc |> to_string() |> String.trim()
  defp is_nil_or_empty?(value), do: is_nil(value) or value == ""
end
