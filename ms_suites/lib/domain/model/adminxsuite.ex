defmodule MsSuitesApp.Domain.Model.AdminXSuite do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "adminxsuite" do
    belongs_to :suite, MsSuitesApp.Domain.Model.Suites,
               foreign_key: :id_suite,
               references: :id_suite,
               type: :string

    belongs_to :administrador, MsSuitesApp.Domain.Model.Users,
               foreign_key: :id_administrador,
               type: :integer
  end

  def changeset(asg, attrs) do
    asg
    |> cast(attrs, [:id_suite, :id_administrador])
    |> validate_required([:id_suite, :id_administrador])
  end
end

