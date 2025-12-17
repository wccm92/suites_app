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
    field :diasmora, :integer
    field :estado, :boolean

    many_to_many :eventos, MsSuitesApp.Domain.Model.Evento,
                 join_through: MsSuitesApp.Domain.Model.SuiteXEvento,
                 join_keys: [id_suite: :id_suite, id_evento: :id_evento]

    many_to_many :administradores, MsSuitesApp.Domain.Model.Users,
                 join_through: MsSuitesApp.Domain.Model.AdminXSuite,
                 join_keys: [id_suite: :id_suite, id_administrador: :id]
  end

  def changeset(suite, attrs) do
    suite
    |> cast(attrs, [:id_suite, :tribuna, :id_propietario, :saldo, :obs, :capacidad, :estado])
    |> validate_required([:id_suite, :tribuna])
  end
end
