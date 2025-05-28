defmodule EngineSystem.Engine.DSL.EnvironmentBuilder do
  @moduledoc """
  I handle the environment DSL for engine definitions.

  I manage:
  - Environment structure definition
  - Field definitions and validation
  - Default value handling
  """

  alias EngineSystem.Engine.DSL.Utils

  @doc """
  I define the environment structure for the engine.

  ## Parameters

  - `env_args` - Environment arguments including name and default
  - `block` - Block containing field definitions

  ## Returns

  Quoted AST for environment definition
  """
  defmacro environment(env_args, do: block) do
    quote do
      Module.put_attribute(__MODULE__, :current_env_fields, [])
      unquote(block)

      spec_data = Module.get_attribute(__MODULE__, :engine_spec_data)
      fields = Module.get_attribute(__MODULE__, :current_env_fields) |> Enum.reverse()

      # Extract name and default from the keyword list
      [{env_name, default_value}] = unquote(env_args)

      env_spec = %{
        name: env_name,
        default: default_value,
        fields: fields
      }

      updated_spec = %{spec_data | env_spec: env_spec}
      Module.put_attribute(__MODULE__, :engine_spec_data, updated_spec)
      Module.delete_attribute(__MODULE__, :current_env_fields)
    end
  end

  @doc """
  I validate an environment specification.

  ## Parameters

  - `env_spec` - The environment specification to validate

  ## Returns

  - `:ok` if valid
  - `{:error, reason}` if invalid
  """
  @spec validate_env_spec(map()) :: :ok | {:error, any()}
  def validate_env_spec(%{name: name, default: _default, fields: fields})
      when is_atom(name) and is_list(fields) do
    validate_fields(fields)
  end

  def validate_env_spec(_), do: {:error, :invalid_env_spec}

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
  I generate field definitions from an environment map by inferring types from values.

  This function analyzes the map structure and creates field definitions automatically,
  eliminating the need for explicit field declarations.
  """
  def generate_fields_from_map(env_map) do
    Utils.generate_fields_from_map(env_map)
  end

  # Add new simplified environment macro
  defmacro environment(do: env_map_ast) do
    quote do
      # Process the simplified environment syntax
      env_map = unquote(env_map_ast)

      # Generate field definitions from the map automatically
      fields = EngineSystem.Engine.DSL.EnvironmentBuilder.generate_fields_from_map(env_map)

      spec_data = Module.get_attribute(__MODULE__, :engine_spec_data)

      env_spec = %{
        # Use generic name since it's not provided
        name: :environment,
        default: env_map,
        fields: fields
      }

      updated_spec = %{spec_data | env_spec: env_spec}
      Module.put_attribute(__MODULE__, :engine_spec_data, updated_spec)
    end
  end
end
