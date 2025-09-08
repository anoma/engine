import Config

# Configure logger for tests
config :logger,
  level: :warn

# Disable file generation during tests
config :engine_system,
  compile_engines: false,
  generate_diagrams: false