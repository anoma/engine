# General application configuration for EngineSystem
import Config

# Configure logger
config :logger, :console,
  format: "[$level] $message\n",
  metadata: [:request_id]

# Configure logger level
config :logger,
  level: :info

# Configure EngineSystem
config :engine_system,
  # Whether to compile engines by default
  compile_engines: false,
  # Whether to generate diagrams by default
  generate_diagrams: false,
  # Default output directory for diagrams
  diagram_output_dir: "docs/diagrams"

# Import environment specific config
if File.exists?("config/#{config_env()}.exs") do
  import_config "#{config_env()}.exs"
end
