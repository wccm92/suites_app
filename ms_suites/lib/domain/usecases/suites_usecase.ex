defmodule MsSuitesApp.Domain.SuitesUsecase do
  import Ecto.Query, warn: false

  alias MsSuitesApp.Infrastructure.Adapters.Repo
  alias MsSuitesApp.Domain.Model.Suites

  require Logger

  @doc """
  Devuelve TODAS las suites (equivalente a: SELECT * FROM suites).
  """

  @spec handle_list_suites() ::
          {:ok, %{status: pos_integer(), body: map()}}
          | {:error, term()}
  def handle_list_suites do
    with {:ok, suites} <- fetch_suites(),
         {:ok, body} <- build_body(suites) do
      {:ok, %{status: 200, body: body}}
    else
      {:error, reason} = error ->
        Logger.error("Error en handle_list_suites: #{inspect(reason)}")
        error
    end
  end

  # Paso 1: obtener suites desde BD
  defp fetch_suites do
    Logger.debug("Consultando suites en BD")

    suites = Repo.all(Suites)

    Logger.debug("BD devolvió #{length(suites)} suites")
    {:ok, suites}
  rescue
    e ->
      Logger.error("Error consultando BD: #{Exception.message(e)}")
      {:error, {:db_error, e}}
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
        #tribuna: s.tribuna,
        #id_propietario: s.id_propietario,
        #saldo: s.saldo,          # si Decimal te da problemas, luego lo pasamos a string
        #obs: s.obs,
        capacidad: s.capacidad,
        #estado: s.estado
      }
    end
  @doc """
  Devuelve solo las suites activas (estado = true), por si luego lo necesitas.
  """
 #def list_active_suites do
 #  from(s in Suite, where: s.estado == true)
 #  |> Repo.all()
 #end

 #@doc """
 #Obtiene una suite por id_suite. Lanza error si no existe.
 #"""
 #def get_suite!(id_suite) do
 #  Repo.get!(Suite, id_suite)
 #end
end
