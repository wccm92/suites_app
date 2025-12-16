defmodule MsSuitesApp.Domain.LoginUsecase do
  alias MsSuitesApp.Infrastructure.Adapters.Users
  alias MsSuitesApp.Utils.Token

  require Logger

  def login(username, password) do
    with {:ok, user} <- Users.validate_credentials(username, password),
         {:ok, jwt, _claims} <-
           Token.generate_and_sign(%{
             "id_user" => 2, #user.id,
             "username" => "admin" #user.username
           }) do
      {:ok,
        %{
          token: jwt
        }}
    else
      {:error, :inactive_user} ->
      Logger.debug("llego a inactive")
        {:error, :unauthorized, "Usuario inactivo"}

      {:error, :invalid_credentials} ->
        Logger.debug("llego a credenciales")
         {:error, :invalid_credentials}

      _ ->
        Logger.debug("llego a error token")
        {:error, :internal_error, "Error generando token"}
    end
  end

  def validate_session(token) do
    case Token.verify_and_validate(token) do
      {:error, [message: "Invalid token", claim: "exp", claim_val: data]} -> {:error, :expired_suite_session}
      _ -> {:ok, true}
    end
  end

  def validate_event_and_session() do
    {:ok, true}
  end
end