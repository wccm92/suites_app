import Config

config :elixir, :time_zone_database, Tzdata.TimeZoneDatabase

config :ms_sandbox,
       private_key_provider: MsSandbox.Infrastructure.Adapters.PrivateKeyAdapter

config :ms_sandbox,
       timezone: "America/Bogota",
       env: :prod,
       http_port: 8083,
       enable_server: true,
       version: "0.0.1",
       custom_metrics_prefix_name: "ms_sandbox",
       jwt_use_mock: #{jwt-use-mock}#,
       jwt_issuer_url: #{jwt_issuer_url}#,
       secret_name_private_key: "#{secret-name-private-key}#",
       region: "#{secret-region}#"

config :ex_aws,
      region: "#{secret-region}#",
      access_key_id: [{:awscli, "profile_name", 30}],
      secret_access_key: [{:awscli, "profile_name", 30}],
      awscli_auth_adapter: ExAws.STS.AuthCache.AssumeRoleWebIdentityAdapter

config :logger,
       level: #{log-level-ex}#

config :joken,
       default_signer: "secret"
