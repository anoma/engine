defmodule EngineSystem.System.EngineInstanceRegistry do
  @moduledoc """
  I manage the registration and lookup of engine instances.

  I'm responsible for:
  - Registering engine instances when they start
  - Unregistering engine instances when they terminate
  - Looking up engine instance information
  - Listing all active engine instances
  """

  alias EngineSystem.Engine.EngineProcess
  alias EngineSystem.Types.{EngineInstanceInfo, OperationResult}

  @registry_name EngineSystem.Registry

  @type engine_address :: any()

  @type engine_instance_entry :: %{
          pid: pid(),
          type_name: atom() | String.t(),
          type_version: String.t(),
          monitor_ref: reference()
        }

  @type state :: %{
          engine_instances: %{engine_address() => engine_instance_entry()}
        }

  @doc """
  I initialize the engine instance registry.

  This creates the ETS table for fast lookups.

  ## Returns

  - `state()` - An empty registry state
  """
  @spec init() :: state()
  def init do
    # Create an ETS table for fast lookups if it doesn't exist
    case :ets.whereis(@registry_name) do
      :undefined ->
        :ets.new(@registry_name, [:set, :public, :named_table])

      _ ->
        :ok
    end

    %{engine_instances: %{}}
  end

  @doc """
  I register a new engine instance.

  ## Parameters

  - `state` - The current registry state
  - `address` - The address of the engine instance
  - `pid` - The process ID of the engine instance
  - `type_name` - The name of the engine type
  - `type_version` - The version of the engine type

  ## Returns

  - `{:ok, new_state}` - If the engine instance was registered successfully
  """
  @spec register_engine_instance(
          state(),
          engine_address(),
          pid(),
          atom() | String.t(),
          String.t()
        ) :: {:ok, state()}
  def register_engine_instance(state, address, pid, type_name, type_version) do
    # Monitor the process
    monitor_ref = Process.monitor(pid)

    # Store in ETS for fast lookup
    :ets.insert(@registry_name, {address, pid})

    # Store in state for management
    instance_entry = %{
      pid: pid,
      type_name: type_name,
      type_version: type_version,
      monitor_ref: monitor_ref
    }

    new_instances = Map.put(state.engine_instances, address, instance_entry)
    new_state = %{state | engine_instances: new_instances}

    {:ok, new_state}
  end

  @doc """
  I unregister an engine instance.

  ## Parameters

  - `state` - The current registry state
  - `address` - The address of the engine instance to unregister

  ## Returns

  - `{:ok, new_state}` - The engine instance was unregistered
  """
  @spec unregister_engine_instance(state(), engine_address()) :: {:ok, state()}
  def unregister_engine_instance(state, address) do
    # Remove from ETS
    :ets.delete(@registry_name, address)

    # Clean up monitor if it exists
    case Map.get(state.engine_instances, address) do
      %{monitor_ref: monitor_ref} ->
        Process.demonitor(monitor_ref, [:flush])

      nil ->
        :ok
    end

    # Remove from state
    new_instances = Map.delete(state.engine_instances, address)
    new_state = %{state | engine_instances: new_instances}

    {:ok, new_state}
  end

  @doc """
  I handle a process DOWN message for an engine instance.

  ## Parameters

  - `state` - The current registry state
  - `monitor_ref` - The monitor reference of the terminated process

  ## Returns

  - `{:ok, new_state}` - The engine instance was cleaned up
  """
  @spec handle_process_down(state(), reference()) :: {:ok, state()}
  def handle_process_down(state, monitor_ref) do
    # Find the address for this monitor reference
    address_to_remove =
      Enum.find_value(state.engine_instances, fn {address, %{monitor_ref: ref}} ->
        if ref == monitor_ref, do: address, else: nil
      end)

    case address_to_remove do
      nil ->
        {:ok, state}

      address ->
        {_result, new_state} = unregister_engine_instance(state, address)
        {:ok, new_state}
    end
  end

  @doc """
  I get an engine instance by its address.

  ## Parameters

  - `address` - The address of the engine instance

  ## Returns

  - `{:ok, instance_info}` - If the engine instance was found
  - `{:error, :not_found}` - If the engine instance was not found
  """
  @spec get_engine_instance(engine_address()) :: OperationResult.t()
  def get_engine_instance(address) do
    case :ets.lookup(@registry_name, address) do
      [{^address, pid}] ->
        EngineProcess.get_info(pid)

      [] ->
        OperationResult.error(:not_found)
    end
  end

  @doc """
  I list all engine instances.

  ## Returns

  - `{:ok, [instance_info]}` - A list of information about all engine instances
  """
  @spec list_engine_instances() :: OperationResult.t()
  def list_engine_instances do
    # Get all keys from the ETS table
    addresses = :ets.tab2list(@registry_name) |> Enum.map(fn {address, _pid} -> address end)

    # Get info for each instance
    instances =
      Enum.reduce_while(addresses, [], fn address, acc ->
        case get_engine_instance(address) do
          %OperationResult{status: :ok, value: info} ->
            {:cont, [info | acc]}

          _ ->
            {:cont, acc}
        end
      end)

    OperationResult.ok(instances)
  end

  @doc """
  I get the count of registered engine instances.

  ## Parameters

  - `state` - The current registry state

  ## Returns

  - `non_neg_integer()` - The number of registered engine instances
  """
  @spec instance_count(state()) :: non_neg_integer()
  def instance_count(state) do
    map_size(state.engine_instances)
  end
end
