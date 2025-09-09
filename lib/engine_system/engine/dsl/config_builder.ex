defmodule EngineSystem.Engine.DSL.ConfigBuilder do
  @moduledoc """
  I handle the configuration DSL for engine definitions.

  I manage:
  - Configuration structure definition
  - Field definitions and validation
  - Default value handling
  """

  alias EngineSystem.Engine.DSL.Utils

  @doc """
  I define the configuration structure for the engine.

  The configuration defines the initial settings and parameters that the engine
  needs to operate. This includes default values and field specifications for
  type validation and documentation.

  ## Parameters

  - `config_args` - Configuration arguments as a keyword list with name and default value
  - `block` - Block containing field definitions using the `field/2` macro

  ## Examples

  ```elixir
  # Simple configuration with default values
  defengine MyEngine do
    config my_config: %{debug: false, timeout: 5000} do
      field :debug, default: false, type: :boolean
      field :timeout, default: 5000, type: :integer
    end
  end

  # Database configuration example
  defengine DatabaseEngine do
    config db_config: %{
      host: "localhost",
      port: 5432,
      database: "myapp",
      pool_size: 10,
      ssl: false
    } do
      field :host, default: "localhost", type: :string
      field :port, default: 5432, type: :integer
      field :database, default: "myapp", type: :string
      field :pool_size, default: 10, type: :integer
      field :ssl, default: false, type: :boolean
    end
  end

  # Configuration with optional and complex fields
  defengine APIEngine do
    config api_config: %{
      base_url: "https://api.example.com",
      api_key: nil,
      timeout: 30_000,
      retry_attempts: 3,
      headers: %{},
      auth_method: :api_key
    } do
      field :base_url, default: "https://api.example.com", type: :string
      field :api_key, type: :string  # No default, must be provided
      field :timeout, default: 30_000, type: :integer
      field :retry_attempts, default: 3, type: :integer
      field :headers, default: %{}, type: :map
      field :auth_method, default: :api_key, type: :atom
    end
  end

  # Minimal configuration for stateless engines
  defengine StatelessEngine do
    config simple_config: %{mode: :active} do
      field :mode, default: :active, type: :atom
    end
  end
  ```

  ## Field Options

  Each field can specify:
  - `default` - Default value for the field
  - `type` - Expected type for validation
  - `required` - Whether the field is required (boolean)
  - `description` - Human-readable description

  ## Notes

  - Configuration is validated at engine spawn time
  - Missing required fields will cause spawn to fail
  - Default values are merged with provided configuration
  - Field types are used for runtime validation

  """
  defmacro config(config_args, do: block) do
    quote do
      Module.put_attribute(__MODULE__, :current_config_fields, [])
      unquote(block)

      spec_data = Module.get_attribute(__MODULE__, :engine_spec_data)
      fields = Module.get_attribute(__MODULE__, :current_config_fields) |> Enum.reverse()

      # Extract name and default from the keyword list
      [{config_name, default_value}] = unquote(config_args)

      config_spec = %{
        name: config_name,
        default: default_value,
        fields: fields
      }

      updated_spec = %{spec_data | config_spec: config_spec}
      Module.put_attribute(__MODULE__, :engine_spec_data, updated_spec)
      Module.delete_attribute(__MODULE__, :current_config_fields)
    end
  end

  @doc """
  I define a field in the configuration or environment specification.

  Fields specify the structure, types, and constraints for configuration
  or environment data. They provide validation, documentation, and default
  value handling.

  ## Parameters

  - `name` - Field name (atom)
  - `options` - Keyword list of field options (defaults to [])

  ## Available Options

  - `default` - Default value for the field
  - `type` - Expected data type for validation
  - `required` - Whether the field is required (default: false)
  - `description` - Human-readable description of the field
  - `validate` - Custom validation function

  ## Supported Types

  - `:atom` - Atom values
  - `:string` - String values
  - `:integer` - Integer values
  - `:float` - Float values
  - `:boolean` - Boolean values
  - `:map` - Map values
  - `:list` - List values
  - `:tuple` - Tuple values
  - `:pid` - Process ID values
  - `:reference` - Reference values
  - `:any` - Any value type (no validation)

  ## Examples

  ```elixir
  # Basic field with type and default
  field :debug, default: false, type: :boolean

  # Required field without default
  field :api_key, type: :string, required: true

  # Field with description
  field :timeout,
    default: 5000,
    type: :integer,
    description: "Request timeout in milliseconds"

  # Field with custom validation
  field :port,
    default: 8080,
    type: :integer,
    validate: &(&1 > 0 and &1 < 65536)

  # Complex field types
  field :database_config, type: :map, default: %{}
  field :allowed_hosts, type: :list, default: []

  # Optional field with nil default
  field :ssl_cert_path, type: :string, default: nil

  # Field for configuration mode
  field :mode,
    default: :production,
    type: :atom,
    description: "Operating mode: :development, :test, or :production"

  # Numeric fields with constraints
  field :pool_size,
    default: 10,
    type: :integer,
    description: "Connection pool size",
    validate: &(&1 > 0 and &1 <= 100)

  # Boolean flags
  field :enable_logging, default: true, type: :boolean
  field :auto_reconnect, default: false, type: :boolean

  # File path fields
  field :log_file,
    type: :string,
    default: "/tmp/engine.log",
    description: "Path to log file"
  ```

  ## Usage Context

  Fields can be used in two contexts:

  ### Configuration Fields
  ```elixir
  config app_config: %{debug: false} do
    field :debug, default: false, type: :boolean
    field :log_level, default: :info, type: :atom
  end
  ```

  ### Environment Fields
  ```elixir
  environment initial_state: %{counter: 0} do
    field :counter, default: 0, type: :integer
    field :last_updated, type: :integer
  end
  ```

  ## Validation

  - Type validation occurs at runtime when values are set
  - Custom validators receive the field value and return true/false
  - Required fields must be present (not nil)
  - Default values are automatically applied when fields are missing

  ## Notes

  - Field names must be unique within their configuration/environment
  - Type validation helps catch configuration errors early
  - Descriptions are useful for documentation and tooling
  - Custom validators provide flexible validation logic

  """
  defmacro field(name, options \\ []) do
    quote do
      field_def = {unquote(name), unquote(options)}

      # Add to current config fields if we're in config context
      if Module.has_attribute?(__MODULE__, :current_config_fields) do
        current_fields = Module.get_attribute(__MODULE__, :current_config_fields)
        Module.put_attribute(__MODULE__, :current_config_fields, [field_def | current_fields])
      end

      # Add to current env fields if we're in env context
      if Module.has_attribute?(__MODULE__, :current_env_fields) do
        current_fields = Module.get_attribute(__MODULE__, :current_env_fields)
        Module.put_attribute(__MODULE__, :current_env_fields, [field_def | current_fields])
      end
    end
  end

  @doc """
  I validate a configuration specification.

  ## Parameters

  - `config_spec` - The configuration specification to validate

  ## Returns

  - `:ok` if valid
  - `{:error, reason}` if invalid
  """
  @spec validate_config_spec(map()) :: :ok | {:error, any()}
  def validate_config_spec(%{name: name, default: _default, fields: fields})
      when is_atom(name) and is_list(fields) do
    validate_fields(fields)
  end

  def validate_config_spec(_), do: {:error, :invalid_config_spec}

  defp validate_fields([]), do: :ok

  defp validate_fields([{field_name, options} | rest]) when is_atom(field_name) do
    case validate_field_options(options) do
      :ok -> validate_fields(rest)
      error -> error
    end
  end

  defp validate_fields(_), do: {:error, :invalid_field_definition}

  defp validate_field_options(options) when is_list(options) do
    # Validate common field options
    case Keyword.get(options, :type) do
      nil -> :ok
      type when is_atom(type) -> :ok
      _ -> {:error, :invalid_field_type}
    end
  end

  defp validate_field_options(_), do: {:error, :invalid_field_options}

  @doc """
  I generate field definitions from a configuration map by inferring types from values.

  This function analyzes the map structure and creates field definitions automatically,
  eliminating the need for explicit field declarations.
  """
  def generate_fields_from_map(config_map) do
    Utils.generate_fields_from_map(config_map)
  end

  # Add new simplified config macro
  defmacro config(do: config_map_ast) do
    quote do
      # Process the simplified config syntax
      config_map = unquote(config_map_ast)

      # Generate field definitions from the map automatically
      fields = EngineSystem.Engine.DSL.ConfigBuilder.generate_fields_from_map(config_map)

      spec_data = Module.get_attribute(__MODULE__, :engine_spec_data)

      config_spec = %{
        # Use generic name since it's not provided
        name: :config,
        default: config_map,
        fields: fields
      }

      updated_spec = %{spec_data | config_spec: config_spec}
      Module.put_attribute(__MODULE__, :engine_spec_data, updated_spec)
    end
  end
end
