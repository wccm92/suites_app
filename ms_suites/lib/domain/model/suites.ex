defmodule MsSuitesApp.Domain.Model.Suites do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id_suite, :string, autogenerate: false}
  schema "suites" do
    field :tribuna, :integer
    field :id_propietario, :integer
    field :saldo, :decimal
    field :obs, :string
    field :capacidad, :integer
    field :estado, :boolean
  end

  def changeset(suite, attrs) do
    suite
    |> cast(attrs, [:id_suite, :tribuna, :id_propietario, :saldo, :obs, :capacidad, :estado])
    |> validate_required([:id_suite, :tribuna])
  end
end
