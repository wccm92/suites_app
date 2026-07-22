defmodule MsSuitesApp.Domain.RegisterAmparadoUsecase do
  alias MsSuitesApp.Domain.LoginUsecase
  alias MsSuitesApp.Infrastructure.Adapters.SuitesQueryAdapter
  alias MsSuitesApp.Infrastructure.Adapters.Repo

  def handle_register_amparado(id_suite, amparado, token) do
    with {:ok, event_user} <-
           LoginUsecase.validate_event_and_session(token),

         :ok <-
           SuitesQueryAdapter.register_amparado(
             event_user.id,
             id_suite,
             amparado
           ) do
      {:ok,
        %{
          title: "success",
          detail: "Amparado registrado correctamente"
        }}
    else
      {:error, _} = error ->
        error
    end
  end
end