defmodule MsSuitesApp.Infrastructure.Adapters.ParametrosRepo do
  import Ecto.Query
  alias MsSuitesApp.Infrastructure.Adapters.Repo
  alias MsSuitesApp.Domain.Model.Parametros

  def get_diasmora_max do
    from(p in Parametros,
      where: p.desc_parametro == "diasmora",
      select: p.valor,
      limit: 1
    )
    |> Repo.one()
  end

end
