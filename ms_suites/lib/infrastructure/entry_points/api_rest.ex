defmodule MsSuitesApp.Infrastructure.EntryPoint.ApiRest do

  @compile if Mix.env() == :test, do: :export_all

  alias MsSuitesApp.Utils.DataTypeUtils
  alias MsSuitesApp.Domain.SuitesUsecase
  alias MsSuitesApp.Infrastructure.EntryPoint.ErrorHandler
  alias MsSuitesApp.Utils.DataTypeUtils
  alias MsSuitesApp.Domain.Model.NaturalPersonRequest
  alias MsSuitesApp.Domain.Model.EnterprisesRequest
  alias MsSuitesApp.Domain.LoginUsecase
  alias MsSuitesApp.Domain.EventUsecase

  @moduledoc """
  Access point to the rest exposed services
  """

  require Logger
  use Plug.Router
  use Timex

  @natural_person "natural-person"
  @enterprises "enterprises"
  @suites "suites"
  @login "login"
  @evento "evento"

  plug(CORSPlug,
    methods: ["GET", "POST", "PUT", "DELETE"],
    origin: [~r/.*/],
    headers: ["Content-Type", "Accept", "User-Agent"]
  )

  plug(Plug.Logger, log: :debug)
  plug(:match)
  plug(Plug.Parsers, parsers: [:urlencoded, :json], json_decoder: Poison)
  plug(Plug.Telemetry, event_prefix: [:ms_suites, :plug])
  plug(:dispatch)

  forward(
    "/fua/Suites/health",
    to: PlugCheckup,
    init_opts:
      PlugCheckup.Options.new(
        json_encoder: Jason,
        checks: MsSuitesApp.Infrastructure.EntryPoint.HealthCheck.checks()
      )
  )
  get "/suites_app/suites" do
    with {:ok, response} <- SuitesUsecase.handle_list_suites() do
      log_response(@suites, "no-message-id", response)
      build_response(response, conn)
    else
      error -> error |> handle_error(conn)
    end
  end

  post "/suites_app/login" do
    case conn.body_params do
      %{"username" => username, "password" => password} ->
        case LoginUsecase.login(username, password) do
          {:ok, response} ->
            build_response(response, conn)
          error -> error |> handle_error(conn)
        end
    end
  end

  get "/suites_app/get-event" do
    with {:ok, response} <- EventUsecase.get_evento_activo() do
      log_response(@evento, "no-message-id", response)
      build_response(response, conn)
    else
      error -> error |> handle_error(conn)
    end
  end


  match _ do
    conn
    |> handle_not_found(Logger.level())
  end

  def build_response(%{status: status, body: body}, conn) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Poison.encode!(body))
  end

  def build_response(response, conn), do: build_response(%{status: 200, body: response}, conn)

  def build_error_response(%{status: status, body: body}, conn) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Poison.encode!(body))
  end

  def build_error_response(response, conn), do: build_response(%{status: 404, body: response}, conn)

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
    |> build_error_response(conn)
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
