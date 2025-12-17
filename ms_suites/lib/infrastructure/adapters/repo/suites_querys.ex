defmodule MsSuitesApp.Infrastructure.Adapters.SuitesQueryAdapter do

  import Ecto.Query
  alias MsSuitesApp.Infrastructure.Adapters.Repo
  alias MsSuitesApp.Domain.Model.Suites

  def list_suites_by_event_and_admin(event_id, admin_id) do
    from(s in Suites,
      join: e in assoc(s, :eventos),
      join: a in assoc(s, :administradores),
      where: e.id_evento == ^event_id and a.id == ^admin_id,
      distinct: true
    )
    |> Repo.all()
  end
end