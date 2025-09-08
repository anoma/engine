import Config

# Configure logger for development
config :logger,
  level: :debug

# Enable diagram generation in development
config :engine_system,
  generate_diagrams: true,
  diagram_output_dir: "docs/diagrams"