defmodule MsSuitesApp.Domain.Model.SuiteXEvento do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "suitexevento" do
    belongs_to :suite, MsSuitesApp.Domain.Model.Suites,
               foreign_key: :id_suite,
               references: :id_suite,
               type: :string

    belongs_to :evento, MsSuitesApp.Domain.Model.Evento,
               foreign_key: :id_evento,
               references: :id_evento,
               type: :integer

    field :estado, :string
    field :obs, :string
  end

  def changeset(suitexevento, attrs) do
    suitexevento
    |> cast(attrs, [:id_evento, :id_suite, :estado, :saldo, :obs])
    |> validate_required([:id_evento, :id_suite, :estado, :saldo, :obs])
  end
end
