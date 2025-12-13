defmodule MsSuitesApp.Domain.Model.UserRoles do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "user_roles" do
    field :user_id, :integer
    field :role_id, :integer
  end

  def changeset(user_roles, attrs) do
    user_roles
    |> cast(attrs, [:user_id, :role_id])
    |> validate_required([:user_id, :role_id])
  end
end
