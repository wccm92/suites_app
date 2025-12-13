defmodule MsSuitesApp.Application do
  @moduledoc """
  MsSuitesApp application
  """

  @compile if Mix.env() == :test, do: :export_all

  alias MsSuitesApp.Infrastructure.EntryPoint.ApiRest
  alias MsSuitesApp.Config.{AppConfig, ConfigHolder}
  alias MsSuitesApp.Infrastructure.Adapters.Repo

  use Application
  require Logger

  def start(_type, [env]) do
    config = AppConfig.load_config()

    env = Application.get_env(:ms_suites, :env)
    in_test? = {:ok, env == :test}

    children = with_plug_server(config) ++ application_children(in_test?)

    opts = [strategy: :one_for_one, name: MsSuitesApp.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp with_plug_server(%AppConfig{enable_server: true, http_port: port}) do
    Logger.debug("Configure Http server in port #{inspect(port)}. ")
    [{Plug.Cowboy, scheme: :http, plug: ApiRest, options: [port: port]}]
  end

  defp with_plug_server(%AppConfig{enable_server: false}), do: []

  def application_children({:ok, true} = _test_env),
      do: [
        {ConfigHolder, AppConfig.load_config()},
        {Repo, []},
      ]

  def application_children(_other_env),
      do: [
        {ConfigHolder, AppConfig.load_config()},
        {Repo, []},
      ]
end
