defmodule MsSuitesApp.Domain.SuitesDetailUsecase do
  import Ecto.Query, warn: false

  alias MsSuitesApp.Domain.LoginUsecase
  alias MsSuitesApp.Infrastructure.Adapters.Repo
  alias MsSuitesApp.Infrastructure.Adapters.SuitesQueryAdapter
  alias MsSuitesApp.Infrastructure.Adapters.AmparadosQueryAdapter
  alias MsSuitesApp.Domain.Model.Suites
  alias MsSuitesApp.Infrastructure.Adapters.ParametrosRepo

  require Logger

  @doc """
  Devuelve TODAS las suites by id.
  """

  def handle_list_suites_detail(id_suite, token) do
    with {:ok, event_user_info} <- LoginUsecase.validate_event_and_session(token),
         {:ok, suites} <- fetch_suites(id_suite, event_user_info),
         {:ok, true} <- validate_suite_estado(suites),
         {:ok, true} <- validate_suite_mora(suites, suites.exonera),
         suite_alquilada  <- SuitesQueryAdapter.suite_alquilada?(id_suite, event_user_info.id),
         {:ok, body} <- build_body(suites, suite_alquilada) do
      {:ok, body}
    else
      {:error, reason} = error ->
        Logger.error("Error en handle_list_suites: #{inspect(reason)}")
        error
    end
  end

  defp fetch_suites(id_suite, event_user_info) do
    Logger.debug("Consultando el detalle de suites por id_suite")
    suites_detail = SuitesQueryAdapter.list_suites_detail_by_id_suite(
      id_suite,
      event_user_info.id
    )
    Logger.debug("BD devolvió  suites")
    {:ok, enrich_invitados(suites_detail, id_suite, event_user_info.id)}
  rescue
    error ->
      Logger.error("Error consultando BD: #{Exception.message(error)}")
      {:error, {:db_error, error}}
  end

  # Transforma invitados_inscritos (lista de cédulas) en una lista de
  # %{invitado: cedula, amparados: <conteo en amparadoxevento>} y descuenta
  # los amparados de los cupos disponibles (los amparados también ocupan cupo).
  defp enrich_invitados(nil, _id_suite, _id_evento), do: nil

  defp enrich_invitados(
         %{invitados_inscritos: invitados, cupos_disponibles: cupos_base} = detail,
         id_suite,
         id_evento
       ) do
    counts = AmparadosQueryAdapter.count_amparados_by_suite(id_evento, id_suite)
    total_amparados = counts |> Map.values() |> Enum.sum()

    invitados_inscritos =
      Enum.map(invitados, fn invitado ->
        %{invitado: invitado, amparados: Map.get(counts, invitado, 0)}
      end)

    %{
      detail
    | invitados_inscritos: invitados_inscritos,
      cupos_disponibles: cupos_base - total_amparados
    }
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

  defp build_body(%{
    id_suite: id_suite,
    capacidad: capacidad,
    invitados_inscritos: invitados_inscritos,
    cupos_disponibles: cupos_disponibles
  },
         suite_alquilada) do
    {:ok,
      %{
        id_suite: id_suite,
        capacidad: capacidad,
        invitados_inscritos: invitados_inscritos,
        cupos_disponibles: cupos_disponibles,
        suite_alquilada: suite_alquilada
      }}
  end
end