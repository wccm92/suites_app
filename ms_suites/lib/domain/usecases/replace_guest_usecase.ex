defmodule MsSuitesApp.Domain.ReplaceGuestUsecase do
  alias MsSuitesApp.Domain.LoginUsecase
  alias MsSuitesApp.Infrastructure.Adapters.SuitesQueryAdapter
  alias MsSuitesApp.Infrastructure.Adapters.Repo

  def handle_replace_guest(
        id_suite,
        invitado,
        nuevo_invitado,
        token
      ) do
    with {:ok, event_user} <-
           LoginUsecase.validate_event_and_session(token),

         {:ok, registro} <-
           SuitesQueryAdapter.get_guest_registration(
             event_user.id,
             id_suite,
             invitado
           ),

         :ok <- validate_guest_state(registro),

         :ok <-
           validate_new_guest(
             event_user.id,
             nuevo_invitado
           ),

         :ok <-
           replace_guest_transaction(
             registro,
             nuevo_invitado
           ) do
      {:ok,
        %{
          title: "success",
          detail: "Visitante reemplazado correctamente"
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

  defp validate_guest_state(%{estado: "1"}),
       do: {:error, :guest_already_entered}

  defp validate_guest_state(_),
       do: :ok

  defp validate_new_guest(id_evento, documento) do
    cond do
      SuitesQueryAdapter.validate_blacklisted(documento) ->
        {:error, :black_list}

      true ->
        case SuitesQueryAdapter.validate_guess_in_event(id_evento, documento) do
          {:ok, _} ->
            {:error, :visitor_already_registered}

          :not_found ->
            :ok
        end
    end
  end

  defp replace_guest_transaction(
         registro,
         nuevo_documento
       ) do
    case Repo.transaction(fn ->
      SuitesQueryAdapter.update_guest_document(
        registro,
        nuevo_documento
      )

      SuitesQueryAdapter.delete_dependents(
        registro.id_evento,
        registro.id_suite,
        registro.id_visitante
      )
    end) do
      {:ok, _} ->
        :ok

      {:error, _, _, _} ->
        {:error, :replace_failed}
    end
  end
end