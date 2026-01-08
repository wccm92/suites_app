defmodule MsSuitesApp.Domain.Model.Visitante do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id_visitante, :string, autogenerate: false}
  @derive {Jason.Encoder, only: [:id_visitante, :nom_visitante, :observacion]}
  schema "visitante" do
    field :nom_visitante, :string
    field :observacion, :string

  end

  def changeset(visitante, attrs) do
    visitante
    |> cast(attrs, [:id_visitante, :nom_visitante, :observacion])
    |> validate_required([:id_visitante])
    |> update_change(:id_visitante, &String.trim/1)
    |> validate_length(:id_visitante, min: 3, max: 30)
  end
end
