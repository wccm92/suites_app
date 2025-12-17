defmodule MsSuitesApp.Domain.Model.Parametros do
  use Ecto.Schema

  @primary_key {:id_parametro, :integer, autogenerate: false}
  schema "parametros" do
    field :desc_parametro, :string
    field :valor, :string
  end
end

