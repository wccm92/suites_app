import Config

config :elixir, :time_zone_database, Tzdata.TimeZoneDatabase

config :ms_sandbox,
       timezone: "America/Bogota",
       env: :test,
       http_port: 8083,
       enable_server: true,
       version: "0.0.1",
       custom_metrics_prefix_name: "ms_sandbox_test",
       jwt_issuer_url: "https://autenticacion.grupobancolombia.com",

config :logger,
  level: :info

config :joken,
       default_signer: "secret"

config :junit_formatter,
  report_dir: "_build/release",
  automatic_create_dir?: true,
  report_file: "test-junit-report.xml"

config :elixir_structure_manager,
  sonar_base_folder: ""
