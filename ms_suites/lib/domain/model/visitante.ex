defmodule MsSuitesApp.Domain.Model.Visitante do
  use Ecto.Schema

  @primary_key {:id_visitante, :string, autogenerate: false}
  schema "visitante" do
    field :nom_visitante, :string
    field :email, :string
    field :telefono, :string
  end
end
