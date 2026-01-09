defmodule MsSuitesApp.Domain.Model.Blacklist do
  use Ecto.Schema

  @primary_key false
  schema "blacklist" do
    field :cedula, :string
    field :fecha, :date
    field :motivo, :string
  end
end
