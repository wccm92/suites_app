defmodule MsSuitesApp.Config.AppConfig do
  @moduledoc """
   Provides strcut for app-config
  """

  defstruct [
    :env,
    :enable_server,
    :http_port
  ]

  def load_config do
    %__MODULE__{
      env: load(:env),
      enable_server: load(:enable_server),
      http_port: load(:http_port),
    }
  end

  defp load(property_name), do: Application.fetch_env!(:ms_suites, property_name)
end
