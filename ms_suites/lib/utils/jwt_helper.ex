defmodule MsSuitesApp.Utils.JwtHelper do
  @moduledoc """
  Utils from JWT.
  """

  @doc """
  Extract "kid" from JWT.
  """

  def extract_fields(token) do
    case safe_peek_payload(token) do
      {:ok, %JOSE.JWT{fields: fields}} -> {:ok, fields}
      {:error, reason} -> {:error, reason}
    end
  end

  defp safe_peek_payload(token) do
    try do
      {:ok, JOSE.JWT.peek_payload(token)}
    rescue
      error in [ArgumentError, MatchError] -> {:error, :jwt_deserialization_error}
      error -> {:error, :jwt_deserialization_error}
    end
  end
end