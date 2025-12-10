import Config

config :elixir, :time_zone_database, Tzdata.TimeZoneDatabase

config :ms_suites,
       timezone: "America/Bogota",
       env: :prod,
       http_port: 8083,
       enable_server: true,
       version: "0.0.1",
       custom_metrics_prefix_name: "ms_suites"

config :logger,
       level: #{log-level-ex}#

config :ms_suites, MsSuitesApp.Infrastructure.Adapters.Repo,
        database: "db_edcph",
        username: "",
        password: "",
        hostname: "",
        port: 5432

config :ms_suites,
       ecto_repos: [MsSuitesApp.Infrastructure.Adapters.Repo]


