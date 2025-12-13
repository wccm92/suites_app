defmodule MsSuitesApp.Utils.Token do
  use Joken.Config

  @impl true
  def token_config do
    # 1 hora
    default_claims(default_exp: 60 * 60, skip: [:aud, :iss])
  end
end