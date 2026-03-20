defmodule MsSuitesApp.Domain.ParkingUsecase do
  import Ecto.Query, warn: false

  alias MsSuitesApp.Domain.LoginUsecase
  alias MsSuitesApp.Infrastructure.Adapters.Repo
  alias MsSuitesApp.Infrastructure.Adapters.SuitesQueryAdapter
  alias MsSuitesApp.Domain.Model.Suites
  alias MsSuitesApp.Infrastructure.Adapters.ParametrosRepo

  require Logger

  @doc """
  Devuelve TODAS las suites (equivalente a: SELECT * FROM suites).
  """

  def handle_list_lots(token) do
    with {:ok, event_user_info} <- LoginUsecase.validate_event_and_session(token),
         {:ok, parkings} <- fetch_parkings(event_user_info),
         id_parkings = Enum.map(parkings, & &1.id_suite),
         {:ok, suites} <- fetch_parkings_detail(id_parkings, event_user_info),
         {:ok, body} <- build_body(suites) do
      {:ok, body}
    else
      {:error, reason} = error ->
        Logger.error("Error en handle_list_parkin: #{inspect(reason)}")
        error
    end
  end

  defp fetch_parkings(event_user_info) do
    Logger.debug("Consultando parqueaderos por evento y usuario en BD")
    suites = SuitesQueryAdapter.list_parkings_by_event_and_admin(
      event_user_info.id,
      event_user_info.user.id_user
    )
    Logger.debug("BD devolvió #{length(suites)} suites")
    {:ok, suites}
  rescue
    error ->
      Logger.error("Error consultando BD: #{Exception.message(error)}")
      {:error, {:db_error, error}}
  end

  defp fetch_parkings_detail(id_parking, event_user_info) do
    Logger.debug("Consultando el detalle de parqueaderos por las id_suites")
    suites_detail = SuitesQueryAdapter.list_parkings_detail_by_id_parkings(
      id_parking,
      event_user_info.id
    )
    Logger.debug("BD devolvió  suites")
    {:ok, suites_detail}
  rescue
    error ->
      Logger.error("Error consultando BD: #{Exception.message(error)}")
      {:error, {:db_error, error}}
  end

  defp validate_suite_estado(%{estado: false}) do
    {:error, :suite_bloqueada}
  end

  defp validate_suite_estado(%{estado: true}), do: {:ok, true}

  defp validate_suite_mora(%{diasmora: diasmora}, exonera) do
    max_dias =
      case ParametrosRepo.get_diasmora_max() do
        nil -> 0
        v when is_integer(v) -> v
        v when is_binary(v) -> String.to_integer(v)
      end

    if diasmora > max_dias and not exonera do
      {:error, :suite_en_mora}
    else
      {:ok, true}
    end
  rescue
    error ->
      Logger.error("Error consultando parametro diasmora: #{Exception.message(error)}")
      {:error, {:db_error, error}}
  end

  defp get_max_dias do
    case ParametrosRepo.get_diasmora_max() do
      nil -> 0
      v when is_integer(v) -> v
      v when is_binary(v) -> String.to_integer(v)
    end
  end

  defp build_body(suites) do
    parkings =
      Enum.map(suites, fn suite ->
        estado =
          cond do
            suite.estado == false ->
              "deshabilitado"

            suite.diasmora > get_max_dias() and not suite.exonera ->
              "deshabilitado"

            true ->
              "habilitado"
          end

        %{
          estado: estado,
          id_parqueadero: suite.id_suite
        }
      end)

    {:ok, %{parqueadero: parkings}}
  end
end
