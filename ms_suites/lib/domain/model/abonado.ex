defmodule MsSuitesApp.Domain.Model.Abonado do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id_abonado, :string, autogenerate: false}
  @derive {Jason.Encoder, only: [:id_abonado, :id_suite]}
  schema "abonados" do
    field :id_suite, :string
  end

  def changeset(abonado, attrs) do
    abonado
    |> cast(attrs, [:id_abonado, :id_suite])
    |> validate_required([:id_abonado, :id_suite])
    |> update_change(:id_abonado, &String.trim/1)
    |> update_change(:id_suite, &String.trim/1)
    |> validate_length(:id_abonado, min: 3, max: 30)
    |> unique_constraint(:id_abonado, name: "abonados_pkey")
  end
end
