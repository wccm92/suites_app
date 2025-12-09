import Config

config :elixir, :time_zone_database, Tzdata.TimeZoneDatabase

config :ms_sandbox,
       timezone: "America/Bogota",
       env: :dev,
       http_port: 8083,
       enable_server: true,
       version: "0.0.1",
       custom_metrics_prefix_name: "ms_sandbox_local",
       jwt_issuer_url: "https://autenticacion.grupobancolombia.com",

config :logger,
       level: :debug

config :joken,
       default_signer: "secret"
