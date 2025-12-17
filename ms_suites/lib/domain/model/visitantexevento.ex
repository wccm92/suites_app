defmodule MsSuitesApp.Domain.Model.VisitanteXEvento do
  use Ecto.Schema

  @primary_key false
  schema "visitantexevento" do
    field :id_evento, :integer
    field :id_suite, :string

    belongs_to :visitante, MsSuitesApp.Domain.Model.Visitante,
               foreign_key: :id_visitante,
               references: :id_visitante,
               type: :string
  end
end
