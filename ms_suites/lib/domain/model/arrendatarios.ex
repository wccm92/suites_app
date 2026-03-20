defmodule MsSuitesApp.Domain.Model.Arrendatarios do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:username, :string, autogenerate: false}
  schema "arrendatarios" do
    field :email, :string
    field :password_hash, :string
    field :is_active, :boolean
    field :created_at, :utc_datetime
    field :cel, :integer
    field :id_evento, :integer
  end

  def changeset(users, attrs) do
    users
    |> cast(attrs, [:username, :password_hash, :is_active])
    |> validate_required([:username, :password_hash, :is_active])
  end
end
