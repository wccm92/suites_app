defmodule MsSuitesApp.Domain.GetSeasonTicketHoldersUsecase do
  @moduledoc """
  Consulta de abonados (season ticket holders) de una suite.

  Contrato API GET `/suites_app/get_season_ticket_holders/:id_suite`.
  Respuesta exitosa (http 200):

      %{abonados: [%{id_abonado: "1047451430"}, ...]}
  """

  require Logger

  alias MsSuitesApp.Domain.LoginUsecase
  alias MsSuitesApp.Infrastructure.Adapters.AbonadosQueryAdapter

  def handle_get_season_ticket_holders(id_suite, token) do
    with {:ok, _event_user} <-
           LoginUsecase.validate_event_and_session(token, "profile_validation_enable"),
         {:ok, abonados} <- fetch_abonados(id_suite) do
      {:ok, %{abonados: abonados}}
    else
      {:error, _} = error -> error
    end
  end

  defp fetch_abonados(id_suite) do
    Logger.debug("Consultando abonados de la suite #{inspect(id_suite)}")

    abonados =
      id_suite
      |> AbonadosQueryAdapter.list_season_ticket_holders_by_suite()
      |> Enum.map(&%{id_abonado: &1})

    {:ok, abonados}
  rescue
    error ->
      Logger.error("Error consultando abonados en BD: #{Exception.message(error)}")
      {:error, {:db_error, error}}
  end
end
