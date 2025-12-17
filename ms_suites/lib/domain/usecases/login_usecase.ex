defmodule MsSuitesApp.Domain.LoginUsecase do
  alias MsSuitesApp.Domain.EventUsecase
  alias MsSuitesApp.Infrastructure.Adapters.Users
  alias MsSuitesApp.Utils.JwtHelper
  alias MsSuitesApp.Utils.Token
  alias MsSuitesApp.Utils.DataTypeUtils

  require Logger

  def login(username, password) do
    with {:ok, user} <- Users.validate_credentials(username, password),
         {:ok, jwt, _claims} <-
           Token.generate_and_sign(%{
             "id_user" => user.id,
             "username" => user.username
           }) do
      {:ok,
        %{
          token: jwt
        }}
    else
      {:error, :inactive_user} ->
        Logger.debug("llego a inactive")
        {:error, :inactive_user}

      {:error, :invalid_credentials} ->
        Logger.debug("llego a credenciales")
        {:error, :invalid_credentials}

      _ ->
        Logger.debug("llego a error token")
        {:error, :internal_error, "Error generando token"}
    end
  end

  def validate_event_and_session(token) do
    with {:ok, event} <- EventUsecase.get_evento_activo(),
         {:ok, plain_token} <- validate_session(token) do
      {
        :ok,
        %{
          id_evento: event.evento.id_evento,
          user: DataTypeUtils.normalize(plain_token)
        }
      }
    else
      error -> error
    end
  end

  def validate_session(token) do
    case Token.verify_and_validate(token) do
      {:error, [message: "Invalid token", claim: "exp", claim_val: data]} ->
        {:error, :expired_suite_session}
      _ ->
        try do
          JwtHelper.extract_fields(token)
        rescue
          error -> error
        end
    end
  end
end