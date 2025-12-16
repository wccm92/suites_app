defmodule MsSuitesApp.Domain.SuitesUsecase do
  import Ecto.Query, warn: false

  alias MsSuitesApp.Domain.LoginUsecase
  alias MsSuitesApp.Infrastructure.Adapters.Repo
  alias MsSuitesApp.Domain.Model.Suites

  require Logger

  @doc """
  Devuelve TODAS las suites (equivalente a: SELECT * FROM suites).
  """

  def handle_list_suites(token) do
    with {:ok, event_user_info} <- LoginUsecase.validate_event_and_session(token),
         {:ok, suites} <- fetch_suites(event_user_info),
         {:ok, body} <- build_body(suites) do
      {:ok, body}
    else
      {:error, reason} = error ->
        Logger.error("Error en handle_list_suites: #{inspect(reason)}")
        error
    end
  end

  defp fetch_suites(event_user_info) do
    Logger.debug("Consultando suites por evento y usuario en BD")
    suites = Repo.all(Suites)
    Logger.debug("BD devolvió #{length(suites)} suites")
    {:ok, suites}
  rescue
    error ->
      Logger.error("Error consultando BD: #{Exception.message(error)}")
      {:error, {:db_error, error}}
  end

  defp build_body(suites) when is_list(suites) do
    suites_response =
      suites
      |> Enum.map(&to_response/1)
    {:ok, %{suites: suites_response}}
  rescue
    e ->
      Logger.error("[SuitesUsecase] Error mapeando suites: #{Exception.message(e)}")
      {:error, {:mapping_error, e}}
  end

    defp to_response(%Suites{} = s) do
      %{
        id_suite: s.id_suite,
        capacidad: s.capacidad,
      }
    end
end
