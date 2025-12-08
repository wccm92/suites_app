defmodule MsSandbox.Config.AppConfig do
  @moduledoc """
   Provides strcut for app-config
  """

  defstruct [
    :env,
    :enable_server,
    :http_port,
    :secret_name_private_key,
    :region
  ]

  def load_config do
    %__MODULE__{
      env: load(:env),
      enable_server: load(:enable_server),
      http_port: load(:http_port),
      secret_name_private_key: load(:secret_name_private_key),
      region: load(:region)
    }
  end

  defp load(property_name), do: Application.fetch_env!(:ms_sandbox, property_name)
end
