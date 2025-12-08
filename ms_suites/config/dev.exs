import Config

config :elixir, :time_zone_database, Tzdata.TimeZoneDatabase

config :ms_sandbox,
       private_key_provider: MsSandbox.Infrastructure.Adapters.PrivateKeyAdapter

config :ms_sandbox,
       timezone: "America/Bogota",
       env: :dev,
       http_port: 8083,
       enable_server: true,
       version: "0.0.1",
       custom_metrics_prefix_name: "ms_sandbox_local",
       jwt_use_mock: "true",
       jwt_issuer_url: "https://autenticacion.grupobancolombia.com",
       secret_name_private_key: "",
       region: "us-east-1"

config :ex_aws,
       region: "us-east-1",
       access_key_id: [{:system, "AWS_ACCESS_KEY_ID"}, {:awscli, "default", 30}, :instance_role],
       secret_access_key: [
         {:system, "AWS_SECRET_ACCESS_KEY"},
         {:awscli, "default", 30},
         :instance_role
       ]

config :logger,
       level: :debug

config :joken,
       default_signer: "secret"
