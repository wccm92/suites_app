defmodule MsSuitesApp.Domain.Model.Amparadoxevento do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id_amparado, :string, autogenerate: false}
  @derive {Jason.Encoder,
    only: [:id_amparado, :id_visitante, :id_evento, :id_suite, :estado, :obsingreso]}
  schema "amparadoxevento" do
    field :id_visitante, :string
    field :id_evento, :integer
    field :id_suite, :string
    field :estado, :string
    field :obsingreso, :string
  end

  def changeset(amparado, attrs) do
    amparado
    |> cast(attrs, [:id_amparado, :id_visitante, :id_evento, :id_suite, :estado, :obsingreso])
    |> validate_required([:id_amparado, :id_visitante, :id_evento, :id_suite])
    |> foreign_key_constraint(:id_evento, name: "amparadoxevento_id_evento_fkey")
    |> foreign_key_constraint(:id_suite, name: "amparadoxevento_id_suite_fkey")
    |> foreign_key_constraint(:id_visitante,
         name: "amparadoxevento_id_visitante_id_evento_fkey"
       )
    |> unique_constraint(:id_amparado, name: "amparadoxevento_pkey")
  end
end