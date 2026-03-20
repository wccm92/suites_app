defmodule MsSuitesApp.Domain.Model.ArrendatarioXSuite do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "arrendatarioxsuite" do
    belongs_to :suite, MsSuitesApp.Domain.Model.Suites,
               foreign_key: :id_suite,
               references: :id_suite,
               type: :string

    belongs_to :arrendatario, MsSuitesApp.Domain.Model.Arrendatarios,
               foreign_key: :username,
               references: :username,
               type: :string
  end

  def changeset(asg, attrs) do
    asg
    |> cast(attrs, [:id_suite, :username])
    |> validate_required([:id_suite, :username])
  end
end

