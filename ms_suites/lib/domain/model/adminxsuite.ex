defmodule MsSuitesApp.Domain.Model.AdminxSuite do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "adminxsuite" do
    field :id_suite, :string
    field :id_administrador, :integer
  end

  def changeset(asg, attrs) do
    asg
    |> cast(attrs, [:id_suite, :id_administrador])
    |> validate_required([:id_suite, :id_administrador])
  end
end

