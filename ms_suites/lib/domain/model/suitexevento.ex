defmodule MsSuitesApp.Domain.Model.SuitexEvento do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "suitexevento" do
    field :id_evento, :integer
    field :id_suite, :string
    field :estado, :string
    field :obs, :string
  end

  def changeset(suitexevento, attrs) do
    suitexevento
    |> cast(attrs, [:id_evento, :id_suite, :estado, :saldo, :obs])
    |> validate_required([:id_evento, :id_suite, :estado, :saldo, :obs])
  end
end
