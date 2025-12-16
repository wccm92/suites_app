defmodule MsSuites.Auth.BridgeAuthClient do
  @url "http://127.0.0.1:9099/verify"
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
end
