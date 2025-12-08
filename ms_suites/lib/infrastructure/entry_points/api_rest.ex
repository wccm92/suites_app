defmodule MsSandbox.Infrastructure.EntryPoint.ApiRest do

  @compile if Mix.env() == :test, do: :export_all

  alias MsSandbox.Utils.DataTypeUtils
  alias MsSandbox.Domain.SandboxUsecase
  alias MsSandbox.Infrastructure.EntryPoint.ErrorHandler
  alias MsSandbox.Utils.DataTypeUtils
  alias MsSandbox.Domain.Model.NaturalPersonRequest
  alias MsSandbox.Domain.Model.EnterprisesRequest

  @moduledoc """
  Access point to the rest exposed services
  """

  require Logger
  use Plug.Router
  use Timex

  @natural_person "natural-person"
  @enterprises "enterprises"

  plug(CORSPlug,
    methods: ["GET", "POST", "PUT", "DELETE"],
    origin: [~r/.*/],
    headers: ["Content-Type", "Accept", "User-Agent"]
  )

  plug(Plug.Logger, log: :debug)
  plug(:match)
  plug(Plug.Parsers, parsers: [:urlencoded, :json], json_decoder: Poison)
  plug(Plug.Telemetry, event_prefix: [:ms_sandbox, :plug])
  plug(:dispatch)

  forward(
    "/fua/sandbox/health",
    to: PlugCheckup,
    init_opts:
      PlugCheckup.Options.new(
        json_encoder: Jason,
        checks: MsSandbox.Infrastructure.EntryPoint.HealthCheck.checks()
      )
  )

  post "/fua/sandbox/natural-person" do
    with body <- conn.body_params |> DataTypeUtils.normalize(),
         request_id <- body.message_id,
         {:ok, true} <- log_request(@natural_person, body),
         {:ok, body} <- NaturalPersonRequest.validate_request(body),
         {:ok, response} <- SandboxUsecase.handle_natural_person_token(body) do
      log_response(@natural_person, request_id, response)
      build_response(response, conn)
    else
      error -> error |> handle_error(conn)
    end
  end

  post "/fua/sandbox/enterprises" do
    with body <- conn.body_params |> DataTypeUtils.normalize(),
         request_id <- body.message_id,
         {:ok, true} <- log_request(@enterprises, body),
         {:ok, body} <- EnterprisesRequest.validate_request(body),
         {:ok, response} <- SandboxUsecase.handle_enterprises_token(body) do
      log_response(@enterprises, request_id, response)
      build_response(response, conn)
    else
      error -> error |> handle_error(conn)
    end
  end

  def build_response(%{status: status, body: body}, conn) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Poison.encode!(body))
  end

  def build_response(response, conn), do: build_response(%{status: 200, body: response}, conn)

  match _ do
    conn
    |> handle_not_found(Logger.level())
  end

  defp handle_not_found(conn, :debug) do
    %{request_path: path} = conn
    body = Poison.encode!(%{status: 404, path: path})
    send_resp(conn, 404, body)
  end

  defp handle_not_found(conn, _level) do
    send_resp(conn, 404, "")
  end

  defp handle_error(error, conn) do
    error
    |> ErrorHandler.build_error_response()
    |> build_response(conn)
  end

  defp log_request(resource, request) do
    Logger.info(
      %{
        "Resource: " => resource,
        "Request: " => request
      }
    )
    {:ok, true}
  end

  defp log_response(resource, request_id, response) do
    Logger.info(
      %{
        "Resource: " => resource,
        "message_id: " => request_id,
        "Response: " => Poison.encode!(response)
      }
    )
    {:ok, true}
  end
end
