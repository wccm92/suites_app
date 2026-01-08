defmodule MsSuitesApp.Infrastructure.Adapters.SuitesQueryAdapter do

  import Ecto.Query
  alias MsSuitesApp.Infrastructure.Adapters.Repo
  alias MsSuitesApp.Domain.Model.Suites
  alias MsSuitesApp.Domain.Model.VisitanteXEvento
  alias MsSuitesApp.Domain.Model.Visitante

  def list_suites_by_event_and_admin(event_id, admin_id) do
    from(s in Suites,
      join: e in assoc(s, :eventos),
      join: a in assoc(s, :administradores),
      where: e.id_evento == ^event_id and a.id == ^admin_id,
      distinct: true
    )
    |> Repo.all()
  end

  def list_suites_detail_by_id_suite(id_suite, event_id) do
    from(s in Suites,
      left_join: vx in VisitanteXEvento,
      on: vx.id_suite == s.id_suite and vx.id_evento == ^event_id,
      where: s.id_suite == ^id_suite,
      group_by: [
        s.id_suite,
        s.capacidad,
        s.estado,
        s.diasmora
      ],
      select: %{
        id_suite: s.id_suite,
        capacidad: s.capacidad,
        estado: s.estado,
        diasmora: s.diasmora,
        invitados_inscritos:
          fragment(
            "COALESCE(array_agg(DISTINCT ?) FILTER (WHERE ? IS NOT NULL), '{}')",
            vx.id_visitante,
            vx.id_visitante
          ),
        cupos_disponibles:
          fragment("? - COUNT(DISTINCT ?)", s.capacidad, vx.id_visitante)
      }
    )
    |> Repo.one()
  end

  def validate_guess_in_event(id_evento, id_visitante) do
    from(vx in VisitanteXEvento,
      where: vx.id_evento == ^id_evento and vx.id_visitante == ^id_visitante,
      select: vx.id_suite,
      limit: 1
    )
    |> Repo.one()
    |> case do
         nil -> :not_found
         id_suite -> {:ok, id_suite}
       end
  end
end