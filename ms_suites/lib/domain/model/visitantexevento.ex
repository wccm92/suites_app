defmodule MsSuitesApp.Domain.Model.VisitanteXEvento do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "visitantexevento" do
    field :id_suite, :string
    field :id_evento, :integer
    field :id_visitante, :string
    field :estado, :string
  end

  def changeset(vx, attrs) do
    vx
    |> cast(attrs, [:id_suite, :id_evento, :id_visitante, :estado])
    |> validate_required([:id_suite, :id_evento, :id_visitante])
    |> foreign_key_constraint(:id_suite)
    |> foreign_key_constraint(:id_evento)
    |> foreign_key_constraint(:id_visitante)
    |> unique_constraint([:id_evento, :id_visitante])
  end
end