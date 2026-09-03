defmodule MsSuitesApp.Infrastructure.Adapters.AmparadosQueryAdapter do
  @moduledoc """
  Persistencia de amparados (tabla `amparadoxevento`).
  Un amparado es el menor que acompaña a un invitado en el ingreso; queda
  ligado al invitado (`id_visitante`) dentro de un evento y suite.
  """

  import Ecto.Query

  alias MsSuitesApp.Infrastructure.Adapters.Repo
  alias MsSuitesApp.Domain.Model.Amparadoxevento

  @doc """
  Inserta un amparado ligado a un invitado en el evento/suite.
  `estado` y `obsingreso` quedan vacíos (null).
  Devuelve `{:ok, %Amparadoxevento{}}` o `{:error, %Ecto.Changeset{}}`.
  """
  def register_amparado(id_evento, id_suite, id_visitante, id_amparado) do
    %Amparadoxevento{}
    |> Amparadoxevento.changeset(%{
      id_amparado: id_amparado,
      id_visitante: id_visitante,
      id_evento: id_evento,
      id_suite: id_suite
    })
    |> Repo.insert()
  end

  @doc """
  Registra una lista de amparados en modo best-effort: intenta insertar cada
  uno e ignora los que fallen (duplicados, FK, etc.).
  Devuelve la lista de `id_amparado` efectivamente insertados.
  """
  def register_amparados(_id_evento, _id_suite, _id_visitante, []), do: []

  def register_amparados(id_evento, id_suite, id_visitante, amparados)
      when is_list(amparados) do
    amparados
    |> Enum.map(&normalize/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.filter(fn id_amparado ->
      case register_amparado(id_evento, id_suite, id_visitante, id_amparado) do
        {:ok, _} -> true
        {:error, _} -> false
      end
    end)
  end

  @doc """
  Cuenta los amparados de una suite en un evento, agrupados por invitado.
  Devuelve un mapa `%{id_visitante => cantidad}`.
  """
  def count_amparados_by_suite(id_evento, id_suite) do
    from(a in Amparadoxevento,
      where: a.id_evento == ^id_evento and a.id_suite == ^id_suite,
      group_by: a.id_visitante,
      select: {a.id_visitante, count(a.id_amparado)}
    )
    |> Repo.all()
    |> Map.new()
  end

  @doc """
  Elimina los amparados ligados a un invitado dentro de un evento y suite.
  Devuelve la cantidad de filas eliminadas.

  Debe invocarse ANTES de borrar o modificar la fila del invitado en
  `visitantexevento`: la FK `amparadoxevento_id_visitante_id_evento_fkey`
  es NO ACTION, por lo que la BD rechaza tocar al padre con amparados vivos.
  """
  def delete_amparados_by_visitante(id_evento, id_suite, id_visitante) do
    {count, _} =
      from(a in Amparadoxevento,
        where:
          a.id_evento == ^id_evento and
          a.id_suite == ^id_suite and
          a.id_visitante == ^id_visitante
      )
      |> Repo.delete_all()

    count
  end

  defp normalize(value), do: value |> to_string() |> String.trim()
end