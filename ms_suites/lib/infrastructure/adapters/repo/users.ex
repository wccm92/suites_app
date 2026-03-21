defmodule MsSuitesApp.Infrastructure.Adapters.Users do
  import Ecto.Query
  alias MsSuitesApp.Infrastructure.Adapters.Repo
  alias MsSuitesApp.Domain.Model.Users
  alias MsSuitesApp.Domain.Model.Arrendatarios
  alias MsSuitesApp.Infrastructure.Adapters.Password
  alias MsSuites.Auth.BridgeAuthClient


  @mockuser Application.compile_env(:ms_suites, :mockuser)

  def get_by_username(username) do
    Repo.one(from u in Users, where: u.username == ^username)
  end

  def get_by_username_leaseholders(username) do
    Repo.one(from u in Arrendatarios, where: u.username == ^username)
  end

  def validate_credentials(username, password) do
    if @mockuser == true do
      {
        :ok,
        %{
          id: 2,
          username: "prueba"
        }
      }
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

  def validate_credentials_leaseholder(username, password) do
    if @mockuser == true do
      {
        :ok,
        %{
          id: 2,
          username: "prueba"
        }
      }
    else
      case get_by_username_leaseholders(username) do
        nil ->
          {:error, :invalid_credentials}

        %Arrendatarios{is_active: false} ->
          {:error, :inactive_user}

        %Arrendatarios{} = user ->
          if verify_password(password, user.password_hash) do
            {:ok, user}
          else
            {:error, :invalid_credentials}
          end
      end
    end
  end

  def upsert_leaseholder(cedula, hash, id_evento) do
    case Repo.get_by(Arrendatarios, username: cedula) do
      nil ->
        %Arrendatarios{}
        |> Arrendatarios.changeset(%{
          username: cedula,
          password_hash: hash,
          is_active: true,
          id_evento: id_evento
        })
        |> Repo.insert()

      user ->
        cond do
          user.id_evento == id_evento ->
            {:ok, user}

          true ->
            user
            |> Arrendatarios.changeset(%{id_evento: id_evento})
            |> Repo.update()
        end
    end
  end

  defp verify_password(password, hash) do
    BridgeAuthClient.verify_password(hash, password)
  end

  defp verify_password(_password, _hash), do: false
end
