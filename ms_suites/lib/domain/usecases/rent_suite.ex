defmodule MsSuitesApp.Domain.RentSuiteUsecase do
  require Logger

  alias MsSuitesApp.Domain.LoginUsecase
  alias MsSuitesApp.Infrastructure.Adapters.SuitesQueryAdapter
  alias MsSuitesApp.Repo
  alias MsSuitesApp.Domain.Model.Arrendatarios
  alias MsSuites.Auth.BridgeAuthClient
  alias MsSuitesApp.Infrastructure.Adapters.Users
  alias MsSuitesApp.Infrastructure.Adapters.SuitesQueryAdapter


  def handle_rent_suite(id_suite, cedula, token) do
    with {:ok, event_user_info} <- LoginUsecase.validate_event_and_session(token, "profile_validation_enable"),
          {:ok, true} <- validate_suite_admin(id_suite, event_user_info.user.id_user),
         {:ok, hash} <- BridgeAuthClient.hash_password(cedula),
         {:ok, _user} <- Users.upsert_leaseholder(cedula, hash, event_user_info.id),
         {:ok, result} <- SuitesQueryAdapter.upsert_leaseholder_suite(id_suite, cedula),
         {:ok, body} <- build_body(id_suite) do
      {:ok, body}
    else
      {:error, reason} ->
        Logger.error("Error en rentar suite: #{inspect(reason)}")
        {:error, :error_rent_suite}

      other ->
        Logger.error("Error inesperado en rentar suite: #{inspect(other)}")
        {:error, :error_rent_suite}
    end
  end

  defp validate_suite_admin(id_suite, id_admin) do
    case SuitesQueryAdapter.validate_suite_admin(id_suite, id_admin) do
      nil -> {:error, :unauthorized_suite}
      _ -> {:ok, true}
    end
  end

  defp build_body(id_suite) do
    {:ok, %{id_suite: id_suite}}
  end


end
