defmodule MsSuitesApp.Infrastructure.Adapters.Eventos do
  import Ecto.Query
  alias MsSuitesApp.Infrastructure.Adapters.Repo
  alias MsSuitesApp.Domain.Model.Evento

  def get_evento_activo do
    Repo.one(
      from e in Evento,
      where: e.estado == "Activo",
      order_by: [desc: e.fecha_inicio],
      limit: 1
    )
  end
end