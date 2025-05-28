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

  ## Parameters

  - `config_args` - Configuration arguments including name and default
  - `block` - Block containing field definitions

  ## Returns

  Quoted AST for configuration definition
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
  I define a field in the configuration.

  ## Parameters

  - `name` - Field name
  - `options` - Field options (default, type, etc.)

  ## Returns

  Quoted AST for field definition
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
