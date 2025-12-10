defmodule MsSuitesApp.Infrastructure.Adapters.Repo do
  use Ecto.Repo,
      otp_app: :ms_suites,
      adapter: Ecto.Adapters.Postgres
end