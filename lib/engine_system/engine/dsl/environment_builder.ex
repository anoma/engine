defmodule EngineSystem.Engine.DSL.EnvironmentBuilder do
  @moduledoc """
  I handle the environment DSL for engine definitions.

  I manage:
  - Environment structure definition
  - Field definitions and validation
  - Default value handling
  """

  # Suppress warnings for functions used in macro-generated code
  @compile {:no_warn_undefined, {__MODULE__, :create_field_entry, 2}}
  @compile {:nowarn_unused_function, [{:create_field_entry, 2}]}

  alias EngineSystem.Engine.DSL.EnvironmentBuilder
  alias EngineSystem.Engine.DSL.Utils

  @doc """
  I define the environment specification for the engine.

  ## Parameters

  - `name_spec` - Environment specification and default values (optional)
  - `block` - Block containing field definitions

  ## Returns

  Quoted AST for environment definition
  """
  defmacro environment(name_spec \\ :default_env, do: block) do
    quote do
      Module.put_attribute(__MODULE__, :current_env_fields, [])
      unquote(block)

      spec_data = Module.get_attribute(__MODULE__, :engine_spec_data)
      fields = Module.get_attribute(__MODULE__, :current_env_fields) |> Enum.reverse()

      env_spec =
        EnvironmentBuilder.create_env_spec_public(
          unquote(name_spec),
          fields
        )

      updated_spec = %{spec_data | env_spec: env_spec}

      Module.put_attribute(__MODULE__, :engine_spec_data, updated_spec)
      Module.delete_attribute(__MODULE__, :current_env_fields)
    end
  end

  @doc """
  I define the environment specification for the engine (alias for environment).
  Supports both traditional field syntax and simplified map syntax.

  ## Traditional syntax with fields

  ```elixir
  env do
    field(:counter, default: 0, type: :integer)
    field(:enabled, default: true, type: :boolean)
  end
  ```

  ## Simplified map syntax (auto-infers types)

  ```elixir
  env do
    %{
      counter: 0,
      enabled: true
    }
  end
  ```

  ## Returns

  Quoted AST for environment definition
  """
  defmacro env(name_spec \\ :default_env, do: block) do
    # Check if the block is a simple map (simplified syntax) at compile time
    case block do
      {:%{}, _, _} ->
        # Process the simplified env syntax
        quote do
          env_map = unquote(block)

          # Generate field definitions from the map automatically
          fields = Utils.generate_fields_from_map(env_map)

          spec_data = Module.get_attribute(__MODULE__, :engine_spec_data)

          env_spec = %{
            name: :environment,
            default: env_map,
            fields: fields
          }

          updated_spec = %{spec_data | env_spec: env_spec}
          Module.put_attribute(__MODULE__, :engine_spec_data, updated_spec)
        end

      _ ->
        # Traditional syntax with field definitions
        quote do
          environment(unquote(name_spec), do: unquote(block))
        end
    end
  end

  @doc """
  I define a field in the environment.

  ## Parameters

  - `field_def` - Field definition (name or name with options)
  - `options` - Field options (default value, type, etc.)

  ## Returns

  Quoted AST for field definition
  """
  defmacro field(field_def, options \\ []) do
    quote do
      current_fields = Module.get_attribute(__MODULE__, :current_env_fields)

      field_entry =
        __MODULE__.create_field_entry(
          unquote(field_def),
          unquote(options)
        )

      Module.put_attribute(__MODULE__, :current_env_fields, [field_entry | current_fields])
    end
  end

  @doc """
  I generate field definitions from an environment map by inferring types from values.

  This function analyzes the map structure and creates field definitions automatically,
  eliminating the need for explicit field declarations.
  """
  def generate_fields_from_map(env_map) do
    Utils.generate_fields_from_map(env_map)
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
  I create an environment specification from name and fields (public version for macro expansion).
  """
  def create_env_spec_public(name_spec, fields) do
    create_env_spec(name_spec, fields)
  end

  # Helper functions for creating specs
  defp create_env_spec({:__block__, _, [{name, default}]}, fields) when is_atom(name) do
    %{
      name: name,
      default: default,
      fields: fields
    }
  end

  defp create_env_spec([{name, default}], fields) when is_atom(name) do
    %{
      name: name,
      default: default,
      fields: fields
    }
  end

  defp create_env_spec(name, fields) when is_atom(name) do
    %{
      name: name,
      default: %{},
      fields: fields
    }
  end

  # Helper function for field macro
  def create_field_entry({field_name, _, _}, options) when is_atom(field_name) do
    {field_name, options}
  end

  def create_field_entry(field_name, options) when is_atom(field_name) do
    {field_name, options}
  end
end
