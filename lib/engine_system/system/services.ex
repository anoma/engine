defmodule EngineSystem.System.Services do
  @moduledoc """
  I provide the centralized system services for managing engine types and instances.

  I act as a registry for engine types and instances, and provide services for
  creating, finding, and communicating with engines.

  I'm responsible for:
  - Registering and tracking engine type definitions
  - Creating and tracking engine instances
  - Routing messages between engines
  - Providing system-wide information and status

  ### Public API

  I have the following public functionality:

  - `start_link/0` - Start the system services
  - `register_engine_type_spec/4` - Register a new engine type specification
  - `get_engine_type_spec/2` - Get an engine type specification
  - `get_engine_type_info/2` - Get information about an engine type
  - `list_engine_types/0` - List all registered engine types
  - `create_engine_instance/2` - Create a new engine instance
  - `register_engine_instance/4` - Register a new engine instance
  - `unregister_engine_instance/1` - Unregister an engine instance
  - `get_engine_instance/1` - Get an engine instance
  - `list_engine_instances/0` - List all engine instances
  - `send_message/2` - Send a message to an engine
  - `get_system_info/0` - Get information about the system
  """
  use GenServer

  # alias EngineSystem.{
  #   OperationResult,
  #   EngineTypeInfo,
  #   EngineInstanceInfo,
  #   SystemInfo,
  #   MessageEnvelope
  # }

  alias EngineSystem.{
    Types.OperationResult
  }

  alias EngineSystem.Engine.Compilation.Types.EngineSpec
  alias EngineSystem.Engine.EngineProcess
  alias EngineSystem.System.EngineInstanceRegistry

  @registry_name EngineSystem.Registry

  # --- Types --- #

  @type engine_address :: any()
  @type system_version :: String.t()
  @type timestamp :: integer()

  # --- State --- #

  defmodule State do
    @moduledoc false

    @type engine_type_entry :: %{
            module: module(),
            spec: EngineSpec.t(),
            info: EngineSystem.Types.EngineTypeInfo.t()
          }

    @type engine_instance_entry :: %{
            pid: pid(),
            type_name: atom() | String.t(),
            type_version: String.t(),
            monitor_ref: reference()
          }

    @type t :: %__MODULE__{
            engine_types: %{
              {atom() | String.t(), String.t()} => engine_type_entry()
            },
            engine_instances: %{
              EngineSystem.System.Services.engine_address() => engine_instance_entry()
            },
            system_version: EngineSystem.System.Services.system_version(),
            system_started_at: EngineSystem.System.Services.timestamp()
          }

    defstruct engine_types: %{},
              engine_instances: %{},
              system_version: "0.1.0",
              system_started_at: System.system_time(:millisecond)
  end

  # --- Public API --- #

  @doc """
  I start the system services.

  ## Returns

  - `{:ok, pid}` - If the system services were started successfully
  - `{:error, reason}` - If the system services could not be started
  """
  @spec start_link() :: {:ok, pid()} | {:error, any()}
  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  I start the system services with options.

  ## Parameters

  - `_opts` - Options for starting the system services (currently ignored)

  ## Returns

  - `{:ok, pid}` - If the system services were started successfully
  - `{:error, reason}` - If the system services could not be started
  """
  @spec start_link(keyword()) :: {:ok, pid()} | {:error, any()}
  def start_link(_opts) do
    start_link()
  end

  @doc """
  I register a new engine type specification.

  ## Parameters

  - `type_name` - The name of the engine type
  - `type_version` - The version of the engine type
  - `module` - The module containing the engine type definition
  - `spec` - The compiled engine type specification
  - `definition_module` - The module containing the engine type definition (optional)

  ## Returns

  - `{:ok, type_info}` - If the engine type was registered successfully
  - `{:error, reason}` - If the engine type could not be registered
  """
  @spec register_engine_type_spec(
          atom() | String.t(),
          String.t(),
          module(),
          EngineSystem.Engine.Compilation.Types.EngineSpec.t(),
          module() | nil
        ) ::
          OperationResult.t()
  def register_engine_type_spec(type_name, type_version, module, spec, definition_module \\ nil) do
    GenServer.call(
      __MODULE__,
      {:register_engine_type, type_name, type_version, module, spec, definition_module}
    )
  end

  @doc """
  I get an engine type specification.

  ## Parameters

  - `type_name` - The name of the engine type
  - `type_version` - The version of the engine type

  ## Returns

  - `{:ok, spec}` - If the engine type was found
  - `{:error, :not_found}` - If the engine type was not found
  """
  @spec get_engine_type_spec(atom() | String.t(), String.t()) :: OperationResult.t()
  def get_engine_type_spec(type_name, type_version) do
    GenServer.call(__MODULE__, {:get_engine_type_spec, type_name, type_version})
  end

  @doc """
  I get information about an engine type.

  ## Parameters

  - `type_name` - The name of the engine type
  - `type_version` - The version of the engine type

  ## Returns

  - `{:ok, type_info}` - If the engine type was found
  - `{:error, :not_found}` - If the engine type was not found
  """
  @spec get_engine_type_info(atom() | String.t(), String.t()) :: OperationResult.t()
  def get_engine_type_info(type_name, type_version) do
    GenServer.call(__MODULE__, {:get_engine_type_info, type_name, type_version})
  end

  @doc """
  I list all registered engine types.

  ## Returns

  - `{:ok, [type_info]}` - A list of information about all registered engine types
  """
  @spec list_engine_types() :: OperationResult.t()
  def list_engine_types do
    GenServer.call(__MODULE__, :list_engine_types)
  end

  @doc """
  I create a new engine instance.

  ## Parameters

  - `engine_type` - The type of engine to create, as `{type_name, type_version}`
  - `config` - The configuration for the engine instance

  ## Returns

  - `{:ok, address}` - If the engine instance was created successfully
  - `{:error, reason}` - If the engine instance could not be created
  """
  @spec create_engine_instance({atom() | String.t(), String.t()}, any()) :: OperationResult.t()
  def create_engine_instance({type_name, type_version}, config) do
    GenServer.call(__MODULE__, {:create_engine_instance, type_name, type_version, config})
  end

  @doc """
  I register a new engine instance.

  This function is primarily called by engine processes when they start.

  ## Parameters

  - `address` - The address of the engine instance
  - `pid` - The process ID of the engine instance
  - `type_name` - The name of the engine type
  - `type_version` - The version of the engine type

  ## Returns

  - `:ok` - If the engine instance was registered successfully
  """
  @spec register_engine_instance(engine_address(), pid(), atom() | String.t(), String.t()) :: :ok
  def register_engine_instance(address, pid, type_name, type_version) do
    GenServer.cast(__MODULE__, {:register_engine_instance, address, pid, type_name, type_version})
  end

  @doc """
  I unregister an engine instance.

  This function is primarily called by engine processes when they terminate.

  ## Parameters

  - `address` - The address of the engine instance to unregister

  ## Returns

  - `:ok` - The engine instance was unregistered
  """
  @spec unregister_engine_instance(engine_address()) :: :ok
  def unregister_engine_instance(address) do
    GenServer.cast(__MODULE__, {:unregister_engine_instance, address})
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
    EngineInstanceRegistry.get_engine_instance(address)
  end

  @doc """
  I list all engine instances.

  ## Returns

  - `{:ok, [instance_info]}` - A list of information about all engine instances
  """
  @spec list_engine_instances() :: OperationResult.t()
  def list_engine_instances do
    EngineInstanceRegistry.list_engine_instances()
  end

  @doc """
  I send a message to an engine.

  This now implements the formal m-Send rule from the Engine Model paper:
  Messages to processing engines are automatically routed to their mailbox engines.

  ## Parameters

  - `address` - The address of the engine to send the message to
  - `message` - The message to send, as `{tag, payload}` or `{tag, arg1, arg2, ...}`

  ## Returns

  - `{:ok, message_id}` - If the message was sent successfully
  - `{:error, reason}` - If the message could not be sent
  """
  @spec send_message(engine_address(), tuple()) :: OperationResult.t()
  def send_message(address, message) when is_tuple(message) and tuple_size(message) >= 1 do
    # Use the message router to implement formal m-Send rule
    # This will automatically route messages to mailbox engines if needed
    # System sender address
    sender_address = {:engine, node(), :system}
    EngineSystem.MessagePassing.Router.send_message(sender_address, address, message)
  end

  @doc """
  I get information about the system.

  ## Returns

  - `{:ok, system_info}` - Information about the system
  """
  @spec get_system_info() :: OperationResult.t()
  def get_system_info do
    GenServer.call(__MODULE__, :get_system_info)
  end

  # --- GenServer Callbacks --- #

  @impl GenServer
  def init(_) do
    # Create an ETS table for fast lookups
    :ets.new(@registry_name, [:set, :public, :named_table])

    {:ok, %State{}}
  end

  @impl GenServer
  def handle_call(
        {:register_engine_type, type_name, type_version, module, spec, definition_module},
        _from,
        state
      ) do
    IO.puts(
      "Services: Received :register_engine_type for #{inspect(type_name)} v#{inspect(type_version)}"
    )

    type_key = {type_name, type_version}

    if Map.has_key?(state.engine_types, type_key) do
      reason = {:already_registered, type_key}
      IO.puts("Services: Engine type #{inspect(type_key)} already registered.")
      {:reply, OperationResult.error(reason), state}
    else
      type_info = %EngineSystem.Types.EngineTypeInfo{
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

      IO.puts(
        "Services: Successfully registered #{inspect(type_key)}. New engine_types count: #{map_size(new_engine_types)}"
      )

      {:reply, OperationResult.ok(type_info), %{state | engine_types: new_engine_types}}
    end
  end

  def handle_call({:get_engine_type_spec, type_name, type_version}, _from, state) do
    IO.puts(
      "Services: Received :get_engine_type_spec for #{inspect(type_name)} v#{inspect(type_version)}. Current types: #{inspect(Map.keys(state.engine_types))}"
    )

    type_key = {type_name, type_version}

    case Map.get(state.engine_types, type_key) do
      nil ->
        IO.puts("Services: Type #{inspect(type_key)} not found.")
        {:reply, OperationResult.error(:type_not_found), state}

      %{spec: spec} ->
        IO.puts("Services: Type #{inspect(type_key)} found.")
        {:reply, OperationResult.ok(spec), state}
    end
  end

    def handle_call({:get_engine_type_info, type_name, type_version}, _from, state) do
    # Look up the engine type in the state
    key = {type_name, type_version}

    IO.puts(
      "Services: Received :get_engine_type_info for #{inspect(type_name)} v#{inspect(type_version)}. Current types: #{inspect(Map.keys(state.engine_types))}"
    )

    IO.puts("Services: Looking for key #{inspect(key)}")
    IO.puts("Services: Available keys: #{inspect(Map.keys(state.engine_types))}")
    IO.puts("Services: Key equality check: #{inspect(Enum.any?(Map.keys(state.engine_types), fn k -> k == key end))}")

    # More detailed debugging
    Enum.each(Map.keys(state.engine_types), fn {stored_name, stored_version} ->
      {search_name, search_version} = key
      IO.puts("Comparing stored: #{inspect(stored_name)} (#{inspect(:erlang.phash2(stored_name))}) vs search: #{inspect(search_name)} (#{inspect(:erlang.phash2(search_name))})")
      IO.puts("Name equality: #{stored_name == search_name}, Version equality: #{stored_version == search_version}")
      IO.puts("Stored atom info: #{inspect(stored_name)} is_atom: #{is_atom(stored_name)}")
      IO.puts("Search atom info: #{inspect(search_name)} is_atom: #{is_atom(search_name)}")
      IO.puts("Atom to_string comparison: '#{to_string(stored_name)}' vs '#{to_string(search_name)}'")
    end)

    case Map.get(state.engine_types, key) do
      nil ->
        IO.puts("Services: Type #{inspect(key)} not found in get_engine_type_info.")
        {:reply, OperationResult.error(:not_found), state}

      entry ->
        IO.puts("Services: Type #{inspect(key)} found in get_engine_type_info.")
        {:reply, OperationResult.ok(entry.info), state}
    end
  end

  def handle_call(:list_engine_types, _from, state) do
    # Extract all type infos from the state
    type_infos = Enum.map(state.engine_types, fn {_key, entry} -> entry.info end)

    {:reply, OperationResult.ok(type_infos), state}
  end

  def handle_call({:create_engine_instance, type_name, type_version, config}, _from, state) do
    # Look up the engine type in the state
    key = {type_name, type_version}

    IO.puts(
      "Creating engine instance for type: #{inspect(type_name)}, version: #{inspect(type_version)}"
    )

    IO.puts("Available engine types: #{inspect(Map.keys(state.engine_types))}")

    case Map.get(state.engine_types, key) do
      nil ->
        IO.puts("Engine type not found: #{inspect(key)}")
        {:reply, OperationResult.error(:type_not_found), state}

      entry ->
        IO.puts("Found engine type, starting process...")
        # Start the engine process with the spec directly
        case EngineProcess.start_link(type_name, type_version, config, entry.spec) do
          {:ok, pid} ->
            IO.puts("Engine process started with PID: #{inspect(pid)}")
            # Wait for the engine to register itself
            # In a real system, we would use a more reliable mechanism
            IO.puts("Waiting for engine to register itself...")
            # Increased timeout to 500ms
            Process.sleep(500)

            # Get the engine address from the process
            IO.puts("Getting engine info...")

            case EngineProcess.get_info(pid) do
              %EngineSystem.Types.OperationResult{status: :ok, value: info} ->
                IO.puts("Got engine info: #{inspect(info.address)}")
                {:reply, OperationResult.ok(info.address), state}

              error ->
                IO.puts("Failed to get engine info: #{inspect(error)}")
                {:reply, OperationResult.error(:failed_to_get_address), state}
            end

          {:error, reason} ->
            IO.puts("Failed to start engine process: #{inspect(reason)}")
            {:reply, OperationResult.error(reason), state}
        end
    end
  end

  def handle_call(:get_system_info, _from, state) do
    # Get the number of registered types and instances
    type_count = map_size(state.engine_types)
    instance_count = map_size(state.engine_instances)

    # Create the system info struct
    system_info = %EngineSystem.Types.SystemInfo{
      system_version: state.system_version,
      library_version: Application.spec(:engine_system, :vsn) || "dev",
      registered_engine_types_summary: %{
        count: type_count,
        types: Enum.map(state.engine_types, fn {{name, version}, _} -> {name, version} end)
      },
      running_instances_count: instance_count,
      started_at: state.system_started_at
    }

    {:reply, OperationResult.ok(system_info), state}
  end

  @impl GenServer
  def handle_cast({:register_engine_instance, address, pid, type_name, type_version}, state) do
    # Monitor the engine process
    ref = Process.monitor(pid)

    # Store the engine instance in the ETS table for fast lookups
    :ets.insert(@registry_name, {address, pid})

    # Store instance details in the state for monitoring
    entry = %{
      pid: pid,
      type_name: type_name,
      type_version: type_version,
      monitor_ref: ref
    }

    new_engine_instances = Map.put(state.engine_instances, address, entry)
    new_state = %{state | engine_instances: new_engine_instances}

    {:noreply, new_state}
  end

  def handle_cast({:unregister_engine_instance, address}, state) do
    # Remove the engine instance from the ETS table
    :ets.delete(@registry_name, address)

    # Remove the engine instance from the state
    case Map.get(state.engine_instances, address) do
      nil ->
        {:noreply, state}

      entry ->
        # Demonitor the engine process
        Process.demonitor(entry.monitor_ref, [:flush])

        new_engine_instances = Map.delete(state.engine_instances, address)
        new_state = %{state | engine_instances: new_engine_instances}

        {:noreply, new_state}
    end
  end

  @impl GenServer
  def handle_info({:DOWN, ref, :process, _pid, _reason}, state) do
    # Find the engine instance that died
    case Enum.find(state.engine_instances, fn {_address, entry} -> entry.monitor_ref == ref end) do
      nil ->
        {:noreply, state}

      {address, _entry} ->
        # Remove the engine instance from the ETS table
        :ets.delete(@registry_name, address)

        # Remove the engine instance from the state
        new_engine_instances = Map.delete(state.engine_instances, address)
        new_state = %{state | engine_instances: new_engine_instances}

        {:noreply, new_state}
    end
  end
end
