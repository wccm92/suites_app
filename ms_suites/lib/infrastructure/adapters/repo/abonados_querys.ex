defmodule MsSuitesApp.Infrastructure.Adapters.AbonadosQueryAdapter do
  @moduledoc """
  Consultas de persistencia para los abonados (season ticket holders).
  """

  import Ecto.Query

  alias MsSuitesApp.Infrastructure.Adapters.Repo
  alias MsSuitesApp.Domain.Model.Abonado

  @doc """
  Lista los `id_abonado` registrados en una suite.
  """
  def list_season_ticket_holders_by_suite(id_suite) when is_binary(id_suite) do
    from(a in Abonado,
      where: a.id_suite == ^id_suite,
      select: a.id_abonado
    )
    |> Repo.all()
  end

  @doc """
  Devuelve el `id_suite` en el que un abonado está registrado, o `nil`
  si el abonado no existe en ninguna suite.
  """
  def get_suite_of_abonado(id_abonado) when is_binary(id_abonado) do
    from(a in Abonado,
      where: a.id_abonado == ^id_abonado,
      select: a.id_suite,
      limit: 1
    )
    |> Repo.one()
  end

  @doc """
  Inserta un abonado en la tabla `abonados`.
  Devuelve `{:ok, %Abonado{}}` o `{:error, %Ecto.Changeset{}}`.
  """
  def register_season_ticket_holder(id_abonado, id_suite) do
    %Abonado{}
    |> Abonado.changeset(%{id_abonado: id_abonado, id_suite: id_suite})
    |> Repo.insert()
  end

  @doc """
  Elimina de una suite los abonados cuyos `id_abonado` se reciben en la lista.
  Devuelve la lista de `id_abonado` que efectivamente fueron eliminados.
  """
  def delete_season_ticket_holders(_id_suite, []), do: []

  def delete_season_ticket_holders(id_suite, ids)
      when is_binary(id_suite) and is_list(ids) do
    {_count, deleted} =
      from(a in Abonado,
        where: a.id_suite == ^id_suite and a.id_abonado in ^ids,
        select: a.id_abonado
      )
      |> Repo.delete_all()

    deleted
  end
end