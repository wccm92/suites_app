defmodule MsSuitesApp.Domain.Model.Evento do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id_evento, :integer, autogenerate: false}
  schema "evento" do
    field :cod_evento, :string
    field :desc_evento, :string
    field :fech_creacion, :date
    field :fech_inicio, :date
    field :fech_final, :date
    field :id_user, :integer
    field :estado, :boolean
  end

  def changeset(evento, attrs) do
    evento
    |> cast(attrs, [:id_evento, :cod_evento, :desc_evento, :fech_creacion, :fech_inicio, :fech_final, :estado])
    |> validate_required([:id_evento, :estado])
  end
end
