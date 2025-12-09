import Config

config :elixir, :time_zone_database, Tzdata.TimeZoneDatabase

config :ms_sandbox,
       timezone: "America/Bogota",
       env: :prod,
       http_port: 8083,
       enable_server: true,
       version: "0.0.1",
       custom_metrics_prefix_name: "ms_sandbox",
       jwt_issuer_url: #{jwt_issuer_url}#,

config :logger,
       level: #{log-level-ex}#

config :joken,
       default_signer: "secret"
