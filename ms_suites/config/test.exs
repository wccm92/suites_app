import Config

config :elixir, :time_zone_database, Tzdata.TimeZoneDatabase

config :ms_suites,
       timezone: "America/Bogota",
       env: :test,
       http_port: 8083,
       enable_server: true,
       version: "0.0.1",
       custom_metrics_prefix_name: "ms_suites_test"

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

config :ms_suites, MsSuitesApp.Infrastructure.Adapters.Repo,
       database: "db_edcph",
       username: "",
       password: "",
       hostname: "",
       port: 5432

config :ms_suites,
       ecto_repos: [MsSuitesApp.Infrastructure.Adapters.Repo]
