import Config

# Configure logger for development
config :logger,
  level: :debug

# Development environment settings
config :engine_system,
  generate_diagrams: false,
  diagram_output_dir: "docs/diagrams"