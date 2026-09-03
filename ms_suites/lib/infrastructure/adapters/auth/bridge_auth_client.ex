defmodule MsSuites.Auth.BridgeAuthClient do
  require Logger

  @url "http://127.0.0.1:9099/verify"
  @url_hash "http://127.0.0.1:9099/hash"
  @token_bridge Application.compile_env(:ms_suites, :token_bridge)

  def verify_password(stored_hash, password) do
    body = %{
      hash: stored_hash,
      password: password
    }

    resp =
      Req.post!(
        @url,
        json: body,
        headers: [
          {"authorization", "Bearer " <> @token_bridge}
        ]
      )

    case resp.body do
      %{"ok" => true} -> true
      _ -> false
    end
  rescue
    e ->
      Logger.error("Error verificando password en bridge: #{Exception.message(e)}")
      false
  end
  def hash_password(password) do
    body = %{
      password: password
    }

    resp =
      Req.post!(
        @url_hash,
        json: body,
        headers: [
        {"authorization", "Bearer " <> @token_bridge}
        ]
      )

    case resp.body do
      %{"ok" => true, "hash" => hash} -> {:ok, hash}
      _ -> {:error, :hash_failed}
    end
  rescue
    e ->
      Logger.error("Error generando hash en bridge: #{Exception.message(e)}")
      {:error, :bridge_error}
  end
end
