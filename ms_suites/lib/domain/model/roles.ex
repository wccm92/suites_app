defmodule MsSuitesApp.Domain.Model.Roles do
  use Ecto.Schema
  import Ecto.Changeset


  schema "roles" do
    field :name, :string
    field :description, :string
  end

  def changeset(roles, attrs) do
    roles
    |> cast(attrs, [:name, :description])
    |> validate_required([:name, :description])
  end
end
