defmodule MsSuites.Auth.BridgeAuthClient do
  @url "http://127.0.0.1:9099/verify"
  @url_hash "http://127.0.0.1:9099/hash"
  @token_bridge Application.compile_env(:ms_suites, :token_bridge)

  def verify_password(stored_hash, password) do
    IO.inspect(stored_hash)
    IO.inspect(password)
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
      IO.inspect(e, label: "Bridge error")
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
      IO.inspect(e, label: "Bridge hash error")
      {:error, :bridge_error}
  end
  defp auth_header do
    [
      {"authorization", "Bearer " <> @token_bridge}
    ]
  end
end
