defmodule MsSuitesApp.Domain.DeleteGuestUsecase do
  alias MsSuitesApp.Domain.LoginUsecase
  alias MsSuitesApp.Infrastructure.Adapters.AmparadosQueryAdapter
  alias MsSuitesApp.Infrastructure.Adapters.SuitesQueryAdapter
  alias MsSuitesApp.Infrastructure.Adapters.Repo

  require Logger

  def handle_delete_guest(id_suite, invitado, token) do
    with {:ok, event_user} <- LoginUsecase.validate_event_and_session(token),
         {:ok, registro} <-
           SuitesQueryAdapter.get_guest_registration(
             event_user.id,
             id_suite,
             invitado
           ),
         :ok <- validate_guest_state(registro),
         :ok <- delete_guest_transaction(registro) do
      {:ok,
        %{
          title: "success",
          detail: "Visitante eliminado correctamente"
        }}
    else
      {:error, :guest_not_found} ->
        {:ok,
          %{
            title: "error",
            detail: "Visitante no encontrado"
          }}

      {:error, :guest_already_entered} ->
        {:ok,
          %{
            title: "error",
            detail: "Visitante ya ingresó al evento"
          }}

      {:error, _} = error ->
        error
    end
  end

  defp validate_guest_state(%{estado: "1"}), do: {:error, :guest_already_entered}
  defp validate_guest_state(_), do: :ok

  defp delete_guest_transaction(registro) do
    case Repo.transaction(fn ->
      # Los amparados van primero: la FK hacia visitantexevento es NO ACTION,
      # asi que la BD rechaza borrar al invitado mientras tenga amparados.
      AmparadosQueryAdapter.delete_amparados_by_visitante(
        registro.id_evento,
        registro.id_suite,
        registro.id_visitante
      )

      SuitesQueryAdapter.delete_guest(
        registro.id_evento,
        registro.id_suite,
        registro.id_visitante
      )

      SuitesQueryAdapter.delete_dependents(
        registro.id_evento,
        registro.id_suite,
        registro.id_visitante
      )
    end) do
      {:ok, _} ->
        :ok

      {:error, reason} ->
        Logger.error("Error eliminando invitado: #{inspect(reason)}")
        {:error, :delete_failed}
    end
  rescue
    e in Ecto.ConstraintError ->
      Logger.error("Restriccion violada eliminando invitado: #{inspect(e.constraint)}")
      {:error, :delete_failed}
  end
end