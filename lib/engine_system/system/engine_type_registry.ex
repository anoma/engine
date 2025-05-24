defmodule EngineSystem.System.EngineTypeRegistry do
  @moduledoc """
  I manage the registration and lookup of engine types.

  I'm responsible for:
  - Registering engine type specifications
  - Looking up engine type information
  - Listing all registered engine types
  """

  alias EngineSystem.Engine.Compilation.Types.EngineSpec
  alias EngineSystem.Types.EngineTypeInfo

  @type engine_type_entry :: %{
          module: module(),
          spec: EngineSpec.t(),
          info: EngineTypeInfo.t(),
          definition_module: module() | nil
        }

  @type state :: %{
          engine_types: %{{atom() | String.t(), String.t()} => engine_type_entry()}
        }

  @doc """
  I register a new engine type specification.

  ## Parameters

  - `state` - The current registry state
  - `type_name` - The name of the engine type
  - `type_version` - The version of the engine type
  - `module` - The module containing the engine type definition
  - `spec` - The compiled engine type specification
  - `definition_module` - The module containing the engine type definition (optional)

  ## Returns

  - `{:ok, type_info, new_state}` - If the engine type was registered successfully
  - `{:error, reason, state}` - If the engine type could not be registered
  """
  @spec register_engine_type(
          state(),
          atom() | String.t(),
          String.t(),
          module(),
          EngineSpec.t(),
          module() | nil
        ) :: {:ok, EngineTypeInfo.t(), state()} | {:error, any(), state()}
  def register_engine_type(state, type_name, type_version, module, spec, definition_module \\ nil) do
    type_key = {type_name, type_version}

    if Map.has_key?(state.engine_types, type_key) do
      reason = {:already_registered, type_key}
      {:error, reason, state}
    else
      type_info = %EngineTypeInfo{
        name: type_name,
        version: type_version,
        definition_module: definition_module || module,
        config_spec: spec.config_spec,
        env_spec: spec.env_spec,
        message_interface_spec: spec.message_interface_spec,
        behaviour_spec: spec.behaviour_spec,
        registration_timestamp: System.system_time(:millisecond)
      }

      new_engine_types =
        Map.put(state.engine_types, type_key, %{
          module: module,
          spec: spec,
          info: type_info,
          definition_module: definition_module
        })

      new_state = %{state | engine_types: new_engine_types}
      {:ok, type_info, new_state}
    end
  end

  @doc """
  I get an engine type specification.

  ## Parameters

  - `state` - The current registry state
  - `type_name` - The name of the engine type
  - `type_version` - The version of the engine type

  ## Returns

  - `{:ok, spec}` - If the engine type was found
  - `{:error, :not_found}` - If the engine type was not found
  """
  @spec get_engine_type_spec(state(), atom() | String.t(), String.t()) ::
          {:ok, EngineSpec.t()} | {:error, :not_found}
  def get_engine_type_spec(state, type_name, type_version) do
    type_key = {type_name, type_version}

    case Map.get(state.engine_types, type_key) do
      %{spec: spec} -> {:ok, spec}
      nil -> {:error, :not_found}
    end
  end

  @doc """
  I get information about an engine type.

  ## Parameters

  - `state` - The current registry state
  - `type_name` - The name of the engine type
  - `type_version` - The version of the engine type

  ## Returns

  - `{:ok, type_info}` - If the engine type was found
  - `{:error, :not_found}` - If the engine type was not found
  """
  @spec get_engine_type_info(state(), atom() | String.t(), String.t()) ::
          {:ok, EngineTypeInfo.t()} | {:error, :not_found}
  def get_engine_type_info(state, type_name, type_version) do
    type_key = {type_name, type_version}

    case Map.get(state.engine_types, type_key) do
      %{info: info} -> {:ok, info}
      nil -> {:error, :not_found}
    end
  end

  @doc """
  I list all registered engine types.

  ## Parameters

  - `state` - The current registry state

  ## Returns

  - `{:ok, [type_info]}` - A list of information about all registered engine types
  """
  @spec list_engine_types(state()) :: {:ok, [EngineTypeInfo.t()]}
  def list_engine_types(state) do
    type_infos =
      state.engine_types
      |> Map.values()
      |> Enum.map(& &1.info)

    {:ok, type_infos}
  end

  @doc """
  I initialize an empty engine type registry state.

  ## Returns

  - `state()` - An empty registry state
  """
  @spec init() :: state()
  def init do
    %{engine_types: %{}}
  end
end
