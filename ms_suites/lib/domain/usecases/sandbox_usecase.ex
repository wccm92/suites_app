defmodule MsSandbox.Domain.SandboxUsecase do

  @compile if Mix.env() == :test, do: :export_all

  alias MsSandbox.Utils.DocumentTypeConverter
  alias MsSandbox.Utils.Token

  @timezone Application.compile_env(:ms_sandbox, :timezone)
  @jwt_use_mock Application.compile_env!(:ms_sandbox, :jwt_use_mock)
  @issuer Application.compile_env!(:ms_sandbox, :jwt_issuer_url)
  @private_key_provider Application.compile_env!(:ms_sandbox, :private_key_provider)
  @natural_person "natural-person"
  @enterprises "enterprises"

  def handle_natural_person_token(data) do
    with {:ok, token} <- generate_token() do
      build_success_response(make_jwt_response(data, token, @natural_person), data.channel)
    else
      error ->
        Logger.error("Error en jwt----- #{inspect(error)}")
        error
    end
  end

  def handle_enterprises_token(data) do
    with {:ok, token} <- generate_token() do
      build_success_response(make_jwt_response(data, token, @enterprises), data.channel)
    else
      error ->
        Logger.error("Error en jwt----- #{inspect(error)}")
        error
    end
  end

  defp build_success_response(response_jwt, channel) do
    try do
      {:ok,
        %{
          "data" => %{
            "token" => response_jwt |> encode_result(@jwt_use_mock, channel)
          }
        }
      }
    rescue
      error ->
        error
    end
  end

  defp encode_result(result, "false" = _use_mock, channel) do
    case @private_key_provider.get_private_key_cache() do
      {:ok, %{"private_key" => private_key, "key_id" => key_id}} ->
        extra_claims = %{
          "aud" => channel,
          "iss" => @issuer,
          "sub" => handle_sub_claim(result)
        }
        signer = Joken.Signer.create("RS256", %{"pem" => private_key}, %{"kid" => key_id})
        Map.merge(result, extra_claims) |> Token.generate_and_sign!(signer)
      {:error, reason} ->
        Logger.error("Error obteniendo clave privada: #{inspect(reason)}")
    end
  end

  defp encode_result(result, _use_mock, channel) do
    extra_claims = %{
      "aud" => channel,
      "iss" => @issuer,
      "sub" => handle_sub_claim(result)
    }
    Map.merge(result, extra_claims) |> Token.generate_and_sign!()
  end

  defp handle_sub_claim(result) do
    case result.identity.cid do
      "" -> result.identity.num
      _ -> result.identity.cid
    end
  end

  defp make_jwt_response(data, session_token, authorization_mod) do
    document_original = DocumentTypeConverter.get_id_types_doc_original(data.tip_doc)
    with {:ok, date} <- @timezone |> Timex.now() |> Timex.format("{ISOdate}"),
         {:ok, time} <- @timezone |> Timex.now() |> Timex.format("{ISOtime}"),
         identifier_object = identifier_extract(authorization_mod, data),
         auth_mode = identifier_auth_mode(authorization_mod)
      do
      response = %{
        authentication: %{
          access_token: session_token,
          auth_mode: auth_mode,
          auth_time: date <> " " <> time,
          segment: ""
        },
        identity: %{
          name: data.name,
          doc: data.tip_doc,
          num: data.document_number,
          doc_original: document_original,
          aid: data.aid,
          cid: data.cid,
          mdm: data.mdm_code,
          usr_type: data.usr_type
        },
        authorization: identifier_object,
        additional_data: %{}
      }
    end
  end

  defp identifier_extract("natural-person", data) do
    %{
      entitlement: "",
      owner_doc: "",
      owner_num: "",
      rol: "",
      state: ""
    }
  end

  defp identifier_extract(_, data) do
    %{
      entitlement: data.entitlement,
      owner_doc: data.owner_doc,
      owner_num: data.owner_num,
      rol: data.rol,
      state: ""
    }
  end

  defp identifier_auth_mode("natural-person" = authorization_mod) do
    "PN"
  end

  defp identifier_auth_mode(_) do
    %{
      AK: true
    }
  end

  defp generate_token() do
    {:ok, :crypto.strong_rand_bytes(36) |> Base.url_encode64() |> binary_part(0, 36)}
  end
end