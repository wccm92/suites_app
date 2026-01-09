defmodule MsSuitesApp.Domain.Model.VisitanteXEvento do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "visitantexevento" do
    field :id_suite, :string
    field :id_evento, :integer
    field :id_visitante, :string
  end

  def changeset(vx, attrs) do
    vx
    |> cast(attrs, [:id_suite, :id_evento, :id_visitante])
    |> validate_required([:id_suite, :id_evento, :id_visitante])

      # ✅ Si hay FK reales en BD, esto evita crash y retorna {:error, changeset}
    |> foreign_key_constraint(:id_suite)
    |> foreign_key_constraint(:id_evento)
    |> foreign_key_constraint(:id_visitante)

      # ✅ Si hay UNIQUE/PK (muy probable), evita crash también
      # OJO: el "name" debe ser el nombre real de la constraint en la BD.
      # Si no lo sabes, déjala SIN name primero (a veces funciona) o dime el nombre y la ajusto.
    |> unique_constraint([:id_evento, :id_visitante])
  end
end
