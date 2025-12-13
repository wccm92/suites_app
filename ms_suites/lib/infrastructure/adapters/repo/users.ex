defmodule MsSuitesApp.Infrastructure.Adapters.Users do
  import Ecto.Query
  alias MsSuitesApp.Infrastructure.Adapters.Repo
  alias MsSuitesApp.Domain.Model.Users
  alias MsSuitesApp.Infrastructure.Adapters.Password


  @mockuser Application.compile_env(:ms_suites, :mockuser)

  def get_by_username(username) do
    Repo.one(from u in Users, where: u.username == ^username)
  end

  def validate_credentials(username, password) do
    if @mockuser == true do
      {:ok, username}
    else
    case get_by_username(username) do
      nil ->
        {:error, :invalid_credentials}

      %Users{is_active: false} ->
        {:error, :inactive_user}

      %Users{} = user ->
        if verify_password(password, user.password_hash) do
          {:ok, user}
        else
          {:error, :invalid_credentials}
        end
    end
   end
  end

  defp verify_password(password, "scrypt:" <> _ = hash) do
    Password.verify(password, hash)
  end

  defp verify_password(_password, _hash), do: false
end
