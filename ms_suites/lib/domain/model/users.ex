defmodule MsSuitesApp.Domain.Model.Users do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :integer, autogenerate: false}
  schema "users" do
    field :username, :string
    field :email, :string
    field :password_hash, :string
    field :is_active, :boolean
    field :created_at, :utc_datetime
    field :cel, :integer
  end

  def changeset(users, attrs) do
    users
    |> cast(attrs, [:username, :password_hash, :is_active])
    |> validate_required([:username, :password_hash, :is_active])
  end
end
