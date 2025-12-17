defmodule MsSuitesApp.Domain.SuitesDetailUsecase do
  import Ecto.Query, warn: false

  alias MsSuitesApp.Domain.LoginUsecase
  alias MsSuitesApp.Infrastructure.Adapters.Repo
  alias MsSuitesApp.Infrastructure.Adapters.SuitesQueryAdapter
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
         {:ok, true} <- validate_suite_mora(suites),
         {:ok, body} <- build_body(suites) do
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
      event_user_info.id_evento
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

  defp validate_suite_mora(%{diasmora: diasmora}) do
    max_dias =
      case ParametrosRepo.get_diasmora_max() do
        nil -> 0
        v when is_integer(v) -> v
        v when is_binary(v) -> String.to_integer(v)
      end

    if diasmora > max_dias do
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
  }) do
    {:ok,
      %{
        id_suite: id_suite,
        capacidad: capacidad,
        invitados_inscritos: invitados_inscritos,
        cupos_disponibles: cupos_disponibles
      }}
  end
end
