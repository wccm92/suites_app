defmodule MsSandbox.Infrastructure.Adapters.PrivateKeyAdapter do
  @moduledoc """
  Adapter responsible for retrieving secrets from secrets manager
  """
  use GenServer
  alias MsSandbox.Config.ConfigHolder
  alias MsSandbox.Utils.DataTypeUtils
  @compile if Mix.env == :test, do: :export_all
  @env Application.compile_env(:ms_sandbox, :env)
  require Logger

  def start_link(async_init) do
    GenServer.start_link(__MODULE__, async_init, name: __MODULE__)
  end

  def init(true = _async_init) do
    create_ets()
    send(self(), :get_secret)
    {:ok, nil}
  end

  def init(_async_init) do
    create_ets()
    {:ok, get_initial_secret()}
  end

  defp create_ets do
    :ets.new(:secret_manager_adapter, [:named_table, read_concurrency: true])
  end

  def handle_info(:get_secret, _args) do
    {:noreply, get_initial_secret()}
  end

  defp get_initial_secret() do
    if @env == :prod do
      secret_name_private_key = ConfigHolder.conf.secret_name_private_key
      region = ConfigHolder.conf.region
      secret_private_key = get_secret_value_private_key(secret_name_private_key, region)
      :ets.insert(:secret_manager_adapter, {:secret_private_key, secret_private_key})
      secret_private_key
    end
  end

  def handle_call(:get_secret, _from, state) do
    {:reply, state, state}
  end

  defp get_secret_value_private_key(secret_name, region) do
    case ExAws.SecretsManager.get_secret_value(secret_name)
         |> ExAws.request(region: region) do
      {:ok, %{"SecretString" => secret_string}} ->
        case Jason.decode(secret_string) do
          {:ok, decoded_secret} ->
            {:ok, decoded_secret}
          _ ->
            {:error, "Failed"}
        end
    end
  end

  def get_private_key_cache() do
    if @env == :prod do
      case :ets.lookup(:secret_manager_adapter, :secret_private_key) do
        [{_, {:ok, secret}}] ->
          {:ok, secret}
          Logger.debug("Secret value in the ETS")
          {:ok, %{"private_key" => secret["private_key"], "key_id" => secret["key_id"]}}
        _ ->
          Logger.debug("Secret not found in ETS, calling GenServer to get secret.")
          GenServer.call(__MODULE__, :get_secret)
      end
    else
      Logger.debug("Development environment, returning ConfigHolder.conf.")
      ConfigHolder.conf
    end
  end
end