import Config

# Configure logger for tests
config :logger,
  level: :warning

# Disable file generation during tests
config :engine_system,
  compile_engines: false,
  generate_diagrams: false
