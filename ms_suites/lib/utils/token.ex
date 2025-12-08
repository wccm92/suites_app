defmodule MsSandbox.Utils.Token do
  use Joken.Config
  require Logger
  @issuer Application.compile_env!(:ms_sandbox, :jwt_issuer_url)

  @moduledoc """
  Provides functions for generate JWT
  """
end