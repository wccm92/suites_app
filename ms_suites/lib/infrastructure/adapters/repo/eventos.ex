defmodule MsSuitesApp.Infrastructure.Adapters.Eventos do
  import Ecto.Query
  alias MsSuitesApp.Infrastructure.Adapters.Repo
  alias MsSuitesApp.Domain.Model.Evento

  def get_evento_activo do
    Repo.one(
      from e in Evento,
      where: e.estado == true,
      order_by: [desc: e.fech_inicio],
      limit: 1
    )
  end
end