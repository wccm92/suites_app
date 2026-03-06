defmodule MsSuitesApp.Domain.Model.Evento do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :integer, autogenerate: false}
  schema "eventos" do
    field :evento, :string
    field :descripcion, :string
    field :created_at, :naive_datetime
    field :fecha_inicio, :naive_datetime
    field :fecha_fin, :naive_datetime
    field :estado, :string
  end

  def changeset(eventos, attrs) do
    eventos
    |> cast(attrs, [:evento, :descripcion, :created_at, :fech_creacion, :fech_inicio, :fech_final, :estado])
    |> validate_required([:evento, :estado])
  end
end
