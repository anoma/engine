defmodule EngineSystem.API do
  require Logger

  @moduledoc """
  I provide the core API functions for the EngineSystem.

  I handle:
  - Engine spawning and termination
  - Message sending between engines
  - Engine specification management
  - Instance and system queries
  - System lifecycle management

  ## Public API

  ### System Lifecycle
  - `start_system/0` - Start the EngineSystem application
  - `stop_system/0` - Stop the EngineSystem application

  ### Engine Management
  - `spawn_engine/4` - Spawn a new engine instance
  - `terminate_engine/1` - Terminate an engine instance
  - `send_message/3` - Send a message to an engine

  ### Instance Management
  - `list_instances/0` - List all running engine instances
  - `lookup_instance/1` - Look up information about a running engine instance
  - `lookup_address_by_name/1` - Look up an engine address by name

  ### Engine Specifications
  - `register_spec/1` - Register an engine specification
  - `lookup_spec/2` - Look up an engine specification by name and version
  - `list_specs/0` - List all registered engine specifications

  ### System Operations
  - `get_system_info/0` - Get system-wide information and statistics
  - `fresh_id/0` - Generate a fresh unique ID
  - `validate_message/2` - Validate that a message conforms to an engine's interface
  - `clean_terminated_engines/0` - Clean up terminated engines from the system

  ### Interface Utilities
  - `has_message?/3` - Check if an engine specification supports a specific message tag
  - `get_message_fields/3` - Get the field specification for a message tag from an engine specification
  - `get_message_tags/2` - Get all message tags supported by an engine specification
  - `get_instance_message_tags/1` - Get all message tags supported by a running engine instance
  """

  alias EngineSystem.Engine.{Spec, State}
  alias EngineSystem.Lifecycle
  alias EngineSystem.System.{Registry, Services, Spawner}

  @doc """
  I start the EngineSystem application.

  This initializes the complete OTP application with all necessary supervisors,
  services, and background processes. The system will be ready to accept
  engine definitions, spawn instances, and handle message passing.

  ## Returns

  - `{:ok, [app_list]}` if the system started successfully
  - `{:error, reason}` if startup failed

  ## Examples

      # Basic system startup
      {:ok, apps} = EngineSystem.API.start_system()
      IO.puts("Started applications: \#{inspect(apps)}")

      # Startup with error handling
      case EngineSystem.API.start_system() do
        {:ok, apps} ->
          IO.puts("✅ EngineSystem started successfully")
          IO.puts("Active applications: \#{Enum.join(apps, ", ")}")

          # Verify system is ready
          system_info = EngineSystem.API.get_system_info()
          IO.puts("System uptime: \#{system_info.system_uptime}ms")

        {:error, {:already_started, _app}} ->
          IO.puts("⚠️  EngineSystem already running")
          :ok

        {:error, reason} ->
          IO.puts("❌ Failed to start EngineSystem: \#{inspect(reason)}")
          {:error, reason}
      end

      # Integration with custom application
      defmodule MyApp.Application do
        use Application

        def start(_type, _args) do
          # Start EngineSystem as part of your application
          case EngineSystem.API.start_system() do
            {:ok, _apps} ->
              IO.puts("EngineSystem integrated successfully")

              # Continue with your application setup
              children = [
                # Your other supervisors and workers
                MyApp.WorkerSupervisor,
                MyApp.WebServer
              ]

              Supervisor.start_link(children, strategy: :one_for_one)

            {:error, reason} ->
              {:error, {:engine_system_failed, reason}}
          end
        end
      end

      # Development workflow - safe startup
      def safe_start_system do
        case EngineSystem.API.start_system() do
          {:ok, apps} ->
            IO.puts("🚀 Development environment ready!")
            IO.puts("Started: \#{inspect(apps)}")

            # Verify core components
            info = EngineSystem.API.get_system_info()
            IO.puts("Registry active: \#{info.total_specs >= 0}")
            IO.puts("System ready for engine definitions")

            {:ok, :ready}

          {:error, {:already_started, _}} ->
            IO.puts("📋 System already running - continuing...")
            {:ok, :already_running}

          {:error, reason} ->
            IO.puts("💥 Startup failed: \#{inspect(reason)}")
            {:error, reason}
        end
      end

  ## Notes

  - Safe to call multiple times (idempotent operation)
  - Automatically starts dependencies (:logger, :crypto, etc.)
  - System is immediately ready for engine definitions after success
  - All dynamic supervisors are pre-initialized
  - Registry services are available immediately

  """
  @spec start_system() :: {:ok, [atom()]} | {:error, any()}
  def start_system do
    Lifecycle.start()
  end

  @doc """
  I stop the EngineSystem application gracefully.

  This performs a coordinated shutdown of all system components:
  1. Stops accepting new engine spawns
  2. Gracefully terminates running engines
  3. Cleans up system resources
  4. Stops the OTP application

  ## Returns

  `:ok` when the system has been stopped completely.

  ## Examples

      # Basic system shutdown
      :ok = EngineSystem.API.stop_system()
      IO.puts("EngineSystem stopped")

      # Graceful shutdown with cleanup
      def graceful_shutdown do
        IO.puts("🛑 Initiating EngineSystem shutdown...")

        # Get current state before shutdown
        system_info = try do
          EngineSystem.API.get_system_info()
        rescue
          _ -> %{running_instances: 0, total_instances: 0}
        end

        IO.puts("Stopping system with \#{system_info.running_instances} active engines")

        # Optional: Clean up terminated engines first
        cleaned = try do
          EngineSystem.API.clean_terminated_engines()
        rescue
          _ -> 0
        end

        if cleaned > 0 do
          IO.puts("Pre-shutdown cleanup: \#{cleaned} terminated engines removed")
        end

        # Perform graceful shutdown
        :ok = EngineSystem.API.stop_system()
        IO.puts("✅ EngineSystem shutdown complete")

        %{
          engines_stopped: system_info.running_instances,
          cleanup_performed: cleaned,
          shutdown_time: DateTime.utc_now()
        }
      end

      # Application shutdown integration
      defmodule MyApp.Application do
        def stop(_state) do
          IO.puts("Stopping application components...")

          # Stop EngineSystem last
          :ok = EngineSystem.API.stop_system()
          IO.puts("All systems stopped")
          :ok
        end
      end

      # Development workflow - safe shutdown
      def safe_stop_system do
        try do
          # Check if system is running
          _info = EngineSystem.API.get_system_info()

          IO.puts("🔄 Stopping EngineSystem...")
          :ok = EngineSystem.API.stop_system()
          IO.puts("✅ System stopped successfully")
          :ok
        rescue
          _error ->
            IO.puts("ℹ️  System was not running")
            :ok
        end
      end

      # Emergency shutdown
      def emergency_stop do
        IO.puts("🚨 Emergency shutdown initiated...")

        # Force stop regardless of state
        try do
          :ok = EngineSystem.API.stop_system()
          IO.puts("Emergency stop completed")
        rescue
          error ->
            IO.puts("Emergency stop encountered error: \#{inspect(error)}")
            # Force application stop if needed
            Application.stop(:engine_system)
        end

        :ok
      end

      # Testing helper - reset system
      def reset_for_test do
        # Stop system
        :ok = EngineSystem.API.stop_system()

        # Wait a moment for cleanup
        Process.sleep(100)

        # Start fresh
        {:ok, _} = EngineSystem.API.start_system()

        # Verify clean state
        info = EngineSystem.API.get_system_info()
        assert info.running_instances == 0
        assert info.total_instances == 0

        :ok
      end

  ## Notes

  - Always returns `:ok` (does not fail)
  - Safe to call when system is already stopped
  - Automatically handles dependency cleanup
  - Running engines are terminated as part of shutdown
  - All system resources are released properly

  """
  @spec stop_system() :: :ok
  def stop_system do
    Lifecycle.stop()
  end

  @doc """
  I spawn a new engine instance.

  ## Parameters

  - `engine_module` - The module that defines the engine using the DSL
  - `config` - Initial configuration for the engine (optional)
  - `environment` - Initial environment/local state for the engine (optional)
  - `name` - Optional name for the instance
  - `mailbox_engine_module` - Optional mailbox engine module (defaults to DefaultMailboxEngine)
  - `mailbox_config` - Optional mailbox engine configuration

  ## Returns

  - `{:ok, address}` if the engine was spawned successfully
  - `{:error, reason}` if spawning failed

  ## Examples

      # Spawn an engine with default configuration and default mailbox
      {:ok, address} = EngineSystem.API.spawn_engine(MyKVEngine)

      # Spawn with custom configuration
      config = %{access_mode: :read_only}
      {:ok, address} = EngineSystem.API.spawn_engine(MyKVEngine, config)

      # Spawn with a name
      {:ok, address} = EngineSystem.API.spawn_engine(MyKVEngine, nil, nil, :my_kv_store)

      # Spawn with custom mailbox engine
      {:ok, address} = EngineSystem.API.spawn_engine(
        MyKVEngine,
        %{access_mode: :read_write},
        nil,
        :my_store,
        KVPriorityMailboxEngine,
        %{max_buffer_size: 2000}
      )
  """
  @spec spawn_engine(module(), any(), any(), atom() | nil, module() | nil, any() | nil) ::
          {:ok, State.address()} | {:error, any()}
  def spawn_engine(
        engine_module,
        config \\ nil,
        environment \\ nil,
        name \\ nil,
        mailbox_engine_module \\ nil,
        mailbox_config \\ nil
      ) do
    Spawner.spawn_engine(
      engine_module,
      config,
      environment,
      name,
      mailbox_engine_module,
      mailbox_config
    )
  end

  @doc """
  I spawn a new engine instance with explicit mailbox configuration.

  This provides full control over both processing and mailbox engines.

  ## Parameters

  - `opts` - Keyword list with configuration options

  ## Returns

  - `{:ok, address}` if the engine was spawned successfully
  - `{:error, reason}` if spawning failed

  ## Examples

      # Full specification
      {:ok, address} = EngineSystem.API.spawn_engine_with_mailbox(
        processing_engine: MyKVEngine,
        processing_config: %{access_mode: :read_write},
        processing_env: %{store: %{}},
        mailbox_engine: KVPriorityMailboxEngine,
        mailbox_config: %{max_buffer_size: 5000, batch_size: 20},
        name: :enterprise_kv_store
      )
  """
  @spec spawn_engine_with_mailbox(keyword()) :: {:ok, State.address()} | {:error, any()}
  def spawn_engine_with_mailbox(opts) do
    Spawner.spawn_engine_with_mailbox(opts)
  end

  @doc """
  I send a message to an engine.

  ## Parameters

  - `target_address` - The address of the target engine
  - `message_payload` - The message payload to send
  - `sender_address` - The sender's address (optional)

  ## Returns

  - `:ok` if sending succeeded
  - `{:error, reason}` if sending failed

  ## Examples

      # Send a simple message
      :ok = EngineSystem.API.send_message(target_address, {:get, :my_key})

      # Send with explicit sender
      :ok = EngineSystem.API.send_message(target_address, {:put, :key, :value}, sender_address)
  """
  @spec send_message(State.address(), any(), State.address() | nil) :: :ok | {:error, :not_found}
  def send_message(target_address, message_payload, sender_address \\ nil) do
    # Create a proper message struct for the system
    # Use proper address format: {node_id, engine_id} where both are non_neg_integer
    # System address using proper format
    sender_addr = sender_address || {0, 0}
    message = EngineSystem.System.Message.new(sender_addr, target_address, message_payload)

    # Use the Services.send_message function for actual sending
    Services.send_message(target_address, message)
  end

  @doc """
  I terminate an engine instance gracefully.

  This function stops a running engine and cleans up its resources,
  including its mailbox and any associated processes. The termination
  is handled gracefully to ensure proper cleanup.

  ## Parameters

  - `address` - The address of the engine to terminate (tuple of {node_id, engine_id})

  ## Returns

  - `:ok` if termination succeeded
  - `{:error, :engine_not_found}` if the engine doesn't exist
  - `{:error, reason}` if termination failed for other reasons

  ## Examples

      # Basic engine termination
      {:ok, address} = EngineSystem.API.spawn_engine(MyEngine)
      :ok = EngineSystem.API.terminate_engine(address)

      # Termination with error handling
      case EngineSystem.API.terminate_engine(engine_address) do
        :ok ->
          IO.puts("Engine terminated successfully")
        {:error, :engine_not_found} ->
          IO.puts("Engine was already terminated or never existed")
        {:error, error_reason} ->
          IO.puts("Termination failed: \#{inspect(error_reason)}")
      end

      # Terminate multiple engines
      addresses = [addr1, addr2, addr3]
      results = Enum.map(addresses, &EngineSystem.API.terminate_engine/1)

      # Check if all succeeded
      all_ok = Enum.all?(results, &(&1 == :ok))

      # Terminate by name (if you know the name)
      case EngineSystem.API.lookup_address_by_name(:my_engine) do
        {:ok, address} ->
          EngineSystem.API.terminate_engine(address)
        {:error, :not_found} ->
          IO.puts("Engine not found by name")
      end

      # Safe termination with timeout
      Task.async(fn ->
        EngineSystem.API.terminate_engine(address)
      end)
      |> Task.await(5000)  # Wait up to 5 seconds

  ## Cleanup Process

  When terminating an engine, the system:
  1. Stops accepting new messages
  2. Processes any remaining messages in the queue
  3. Executes cleanup callbacks (if defined)
  4. Terminates the mailbox process
  5. Removes the engine from the registry
  6. Frees allocated resources

  ## Notes

  - Termination is asynchronous but the function waits for completion
  - Messages in flight may be lost during termination
  - Engines can define cleanup behavior in their implementation
  - Terminated engines cannot be restarted (spawn a new instance instead)
  - The engine address becomes invalid after termination

  """
  @spec terminate_engine(State.address()) :: :ok | {:error, :engine_not_found}
  def terminate_engine(address) do
    Spawner.terminate_engine(address)
  end

  @doc """
  I register an engine specification with the system.

  This is typically called automatically when an engine module is compiled,
  but can be called manually if needed for dynamic engine registration.

  ## Parameters

  - `spec` - The engine specification to register (must be a valid EngineSystem.Engine.Spec struct)

  ## Returns

  - `:ok` if registration succeeded
  - `{:error, reason}` if registration failed

  ## Examples

      # Automatic registration (happens when engine is compiled)
      defengine MyEngine do
        version "1.0.0"
        # ... engine definition
      end
      # Spec is automatically registered

      # Manual registration (advanced usage)
      spec = %EngineSystem.Engine.Spec{
        name: :my_dynamic_engine,
        version: "2.0.0",
        mode: :process,
        interface: [
          ping: [],
          pong: []
        ],
        # ... other spec fields
      }
      :ok = EngineSystem.API.register_spec(spec)

      # Verify registration
      {:ok, registered_spec} = EngineSystem.API.lookup_spec(:my_dynamic_engine, "2.0.0")

      # Handle registration errors
      case EngineSystem.API.register_spec(invalid_spec) do
        :ok ->
          IO.puts("Registration successful")
        {:error, :invalid_spec} ->
          IO.puts("Spec validation failed")
        {:error, :already_exists} ->
          IO.puts("Spec already registered")
      end

  """
  @spec register_spec(Spec.t()) :: :ok | {:error, any()}
  def register_spec(spec) do
    Registry.register_spec(spec)
  end

  @doc """
  I look up an engine specification by name and version.

  ## Parameters

  - `name` - The engine type name
  - `version` - The engine type version (nil for latest)

  ## Returns

  - `{:ok, spec}` if found
  - `{:error, :not_found}` if not found
  """
  @spec lookup_spec(atom() | String.t(), String.t() | nil) ::
          {:ok, Spec.t()} | {:error, :not_found}
  def lookup_spec(name, version \\ nil) do
    Registry.lookup_spec(name, version)
  end

  @doc """
  I list all running engine instances.

  ## Returns

  A list of instance information maps.
  """
  @spec list_instances() :: [Registry.instance_info()]
  def list_instances do
    Registry.list_instances()
  end

  @doc """
  I list all registered engine specifications.

  ## Returns

  A list of engine specifications.
  """
  @spec list_specs() :: [Spec.t()]
  def list_specs do
    Registry.list_specs()
  end

  @doc """
  I look up information about a running engine instance.

  This function retrieves detailed information about a specific engine instance,
  including its current status, configuration, specification details, and
  runtime statistics.

  ## Parameters

  - `address` - The engine's address (tuple of {node_id, engine_id})

  ## Returns

  - `{:ok, info}` if the engine exists, where `info` is a map containing:
    - `:address` - The engine's address
    - `:spec_key` - The {name, version} tuple identifying the engine specification
    - `:engine_pid` - The process ID of the engine
    - `:mailbox_pid` - The process ID of the mailbox (if any)
    - `:status` - Current status (`:running`, `:starting`, `:terminated`, etc.)
    - `:name` - Optional name given to the instance
    - `:started_at` - Timestamp when the engine was started
    - Additional implementation-specific fields
  - `{:error, :not_found}` if the engine doesn't exist

  ## Examples

      # Basic instance lookup
      {:ok, address} = EngineSystem.API.spawn_engine(MyEngine, %{}, %{}, :my_instance)
      {:ok, info} = EngineSystem.API.lookup_instance(address)

      IO.puts("Engine status: \#{info.status}")
      IO.puts("Engine name: \#{info.name}")

      # Check if an engine is still running
      case EngineSystem.API.lookup_instance(address) do
        {:ok, %{status: :running}} ->
          IO.puts("Engine is running normally")
        {:ok, %{status: :terminated}} ->
          IO.puts("Engine has terminated")
        {:ok, %{status: status}} ->
          IO.puts("Engine status: \#{status}")
        {:error, :not_found} ->
          IO.puts("Engine not found")
      end

      # Get engine specification info
      case EngineSystem.API.lookup_instance(address) do
        {:ok, %{spec_key: {name, version}}} ->
          IO.puts("Engine type: \#{name} v\#{version}")
          {:ok, spec} = EngineSystem.API.lookup_spec(name, version)
          IO.puts("Interface: \#{inspect(spec.interface)}")
        {:error, :not_found} ->
          IO.puts("Engine not found")
      end

      # Check multiple engines
      addresses = [addr1, addr2, addr3]
      infos = Enum.map(addresses, fn addr ->
        case EngineSystem.API.lookup_instance(addr) do
          {:ok, info} -> {addr, info}
          {:error, :not_found} -> {addr, :not_found}
        end
      end)

      # Filter running engines
      running_engines =
        infos
        |> Enum.filter(fn
          {_addr, %{status: :running}} -> true
          _ -> false
        end)

      # Lookup by name first, then get details
      case EngineSystem.API.lookup_address_by_name(:my_engine) do
        {:ok, address} ->
          {:ok, info} = EngineSystem.API.lookup_instance(address)
          IO.puts("Found engine with status: \#{info.status}")
        {:error, :not_found} ->
          IO.puts("No engine with that name")
      end

  ## Instance Information Fields

  The returned info map contains:
  - **address** - Unique address identifying the instance
  - **spec_key** - Reference to the engine specification used
  - **engine_pid** - Process handling the engine logic
  - **mailbox_pid** - Process handling message queuing (if separate)
  - **status** - Current operational status
  - **name** - Human-readable name (if provided at spawn)
  - **started_at** - Engine start timestamp
  - **config** - Current configuration (implementation-dependent)
  - **stats** - Runtime statistics (implementation-dependent)

  ## Use Cases

  - Health monitoring and diagnostics
  - Engine lifecycle management
  - Debugging and troubleshooting
  - System administration and monitoring
  - Runtime introspection and analysis

  ## Notes

  - Instance information reflects the current state at lookup time
  - Some fields may be implementation-specific
  - Use this for monitoring but avoid polling at high frequency
  - Status values depend on the engine implementation
  - The engine must be registered to be found

  """
  @spec lookup_instance(State.address()) :: {:ok, Registry.instance_info()} | {:error, :not_found}
  def lookup_instance(address) do
    Registry.lookup_instance(address)
  end

  @doc """
  I look up an engine address by name.

  ## Parameters

  - `name` - The engine's name

  ## Returns

  - `{:ok, address}` if found
  - `{:error, :not_found}` if not found
  """
  @spec lookup_address_by_name(atom()) :: {:ok, State.address()} | {:error, :not_found}
  def lookup_address_by_name(name) do
    Registry.lookup_address_by_name(name)
  end

  @doc """
  I get system-wide information and statistics.

  This function provides a comprehensive overview of the EngineSystem's current
  state, including running instances, registered specifications, and system
  health metrics. This is useful for monitoring, debugging, and administration.

  ## Returns

  A map containing system information with the following keys:
  - `:library_version` - Version of the EngineSystem library
  - `:total_instances` - Total number of engine instances (including terminated)
  - `:running_instances` - Number of currently running engine instances
  - `:total_specs` - Number of registered engine specifications
  - `:system_uptime` - System uptime in milliseconds since start

  ## Examples

      # Basic system info
      info = EngineSystem.API.get_system_info()
      IO.inspect(info)
      # Output: %{
      #   library_version: "1.0.0",
      #   total_instances: 15,
      #   running_instances: 12,
      #   total_specs: 8,
      #   system_uptime: 3600000
      # }

      # Check system health
      info = EngineSystem.API.get_system_info()

      if info.running_instances > 0 do
        IO.puts("System is active with \#{info.running_instances} running engines")
      else
        IO.puts("No engines currently running")
      end

      # Monitor system metrics
      info = EngineSystem.API.get_system_info()

      IO.puts("=== EngineSystem Status ===")
      IO.puts("Library Version: \#{info.library_version}")
      IO.puts("Running Engines: \#{info.running_instances}/\#{info.total_instances}")
      IO.puts("Registered Specs: \#{info.total_specs}")
      IO.puts("Uptime: \#{div(info.system_uptime, 1000)} seconds")

      # Calculate engine utilization
      info = EngineSystem.API.get_system_info()

      utilization = if info.total_instances > 0 do
        (info.running_instances / info.total_instances * 100) |> Float.round(1)
      else
        0.0
      end

      IO.puts("Engine utilization: \#{utilization}%")

      # System health dashboard
      defmodule SystemDashboard do
        def print_status do
          info = EngineSystem.API.get_system_info()

          status = cond do
            info.running_instances == 0 -> "🔴 INACTIVE"
            info.running_instances < 5 -> "🟡 LOW ACTIVITY"
            true -> "🟢 ACTIVE"
          end

          IO.puts("System Status: \#{status}")
          IO.puts("Active Engines: \#{info.running_instances}")
          IO.puts("Available Specs: \#{info.total_specs}")
        end
      end

      # Periodic monitoring
      Task.start(fn ->
        :timer.sleep(5000)  # Check every 5 seconds
        info = EngineSystem.API.get_system_info()

        if info.running_instances < 5 do
          IO.puts("WARNING: Low engine count: \#{info.running_instances}")
        end
      end)

  ## Monitoring Use Cases

  - **Health Checks**: Verify system is operational
  - **Capacity Planning**: Monitor engine usage patterns
  - **Performance Monitoring**: Track system metrics over time
  - **Alerting**: Trigger alerts based on thresholds
  - **Debugging**: Diagnose system issues
  - **Administration**: Get overview for management tasks

  ## Metrics Explanation

  - **library_version**: Helps track which version is deployed
  - **total_instances**: Includes all engines ever created (for lifecycle tracking)
  - **running_instances**: Only currently active engines
  - **total_specs**: Number of different engine types available
  - **system_uptime**: Time since EngineSystem was started

  ## Notes

  - Information is gathered at call time (not cached)
  - Uptime resets when the system is restarted
  - Terminated engines are included in total count
  - Use for monitoring but avoid excessive polling
  - Some metrics may be approximate due to concurrent operations

  """
  @spec get_system_info() :: %{
          library_version: any(),
          running_instances: non_neg_integer(),
          system_uptime: integer(),
          total_instances: non_neg_integer(),
          total_specs: non_neg_integer()
        }
  def get_system_info do
    Services.get_system_info()
  end

  @doc """
  I generate a fresh unique ID.

  ## Returns

  A unique integer identifier.
  """
  @spec fresh_id() :: non_neg_integer()
  def fresh_id do
    Services.fresh_id()
  end

  @doc """
  I validate that a message conforms to an engine's interface.

  ## Parameters

  - `engine_address` - The target engine's address
  - `message` - The message to validate

  ## Returns

  - `:ok` if the message is valid
  - `{:error, reason}` if the message is invalid
  """
  @spec validate_message(State.address(), any()) ::
          :ok
          | {:error,
             :engine_not_found
             | :spec_not_found
             | {:unknown_message_tag, any()}}
  def validate_message(engine_address, message) do
    Services.validate_message(engine_address, message)
  end

  @doc """
  I clean up terminated engines from the system.

  This removes terminated engine instances from the system registry,
  freeing up memory and keeping the system organized. I perform
  housekeeping operations to maintain optimal system performance.

  ## Returns

  The number of engines that were cleaned up.

  ## Examples

      # Basic cleanup operation
      cleaned_count = EngineSystem.API.clean_terminated_engines()
      IO.puts("Cleaned up \#{cleaned_count} terminated engines")

      # Regular maintenance routine
      def perform_maintenance do
        IO.puts("🧹 Starting system maintenance...")

        # Get initial state
        before_info = EngineSystem.API.get_system_info()
        IO.puts("Total engines before cleanup: \#{before_info.total_instances}")
        IO.puts("Running engines: \#{before_info.running_instances}")

        # Perform cleanup
        cleaned_count = EngineSystem.API.clean_terminated_engines()

        # Get updated state
        after_info = EngineSystem.API.get_system_info()
        IO.puts("Cleaned up \#{cleaned_count} terminated engines")
        IO.puts("Total engines after cleanup: \#{after_info.total_instances}")

        cleaned_count
      end

      # Scheduled maintenance with threshold
      def scheduled_cleanup(threshold \\ 10) do
        system_info = EngineSystem.API.get_system_info()
        terminated_count = system_info.total_instances - system_info.running_instances

        if terminated_count >= threshold do
          IO.puts("🔧 Threshold reached (\#{terminated_count} terminated engines)")
          cleaned = EngineSystem.API.clean_terminated_engines()
          IO.puts("✅ Cleaned up \#{cleaned} engines")
          {:cleaned, cleaned}
        else
          IO.puts("ℹ️  No cleanup needed (\#{terminated_count} < \#{threshold})")
          {:skipped, terminated_count}
        end
      end

      # Periodic cleanup task
      defmodule SystemMaintenance do
        use GenServer

        def start_link(opts \\ []) do
          GenServer.start_link(__MODULE__, opts, name: __MODULE__)
        end

        def init(opts) do
          interval = Keyword.get(opts, :cleanup_interval, 60_000) # 1 minute
          schedule_cleanup(interval)
          {:ok, %{interval: interval, last_cleanup: 0}}
        end

        def handle_info(:cleanup, state) do
          cleaned = EngineSystem.API.clean_terminated_engines()
          if cleaned > 0 do
            IO.puts("🔄 Periodic cleanup: removed \#{cleaned} terminated engines")
          end

          schedule_cleanup(state.interval)
          {:noreply, %{state | last_cleanup: cleaned}}
        end

        defp schedule_cleanup(interval) do
          Process.send_after(self(), :cleanup, interval)
        end
      end

      # Cleanup with detailed reporting
      def detailed_cleanup_report do
        before_instances = EngineSystem.API.list_instances()
        before_count = length(before_instances)

        # Perform cleanup
        cleaned_count = EngineSystem.API.clean_terminated_engines()

        after_instances = EngineSystem.API.list_instances()
        after_count = length(after_instances)

        report = %{
          before_total: before_count,
          after_total: after_count,
          cleaned: cleaned_count,
          remaining_running: after_count,
          cleanup_percentage: if(before_count > 0, do: (cleaned_count / before_count) * 100, else: 0)
        }

        IO.puts("📊 Cleanup Report:")
        IO.puts("  Before: \#{report.before_total} total engines")
        IO.puts("  Cleaned: \#{report.cleaned} terminated engines")
        IO.puts("  After: \#{report.after_total} running engines")
        IO.puts("  Cleanup rate: \#{Float.round(report.cleanup_percentage, 1)}%")

        report
      end

  ## Use Cases

  - **Memory Management**: Free up resources from terminated engines
  - **System Hygiene**: Keep registry clean and organized
  - **Performance**: Reduce lookup times by removing dead entries
  - **Monitoring**: Track engine lifecycle and cleanup efficiency
  - **Maintenance**: Regular housekeeping operations

  ## Notes

  - Only removes engines that have actually terminated
  - Running engines are never affected
  - Safe to call frequently (minimal performance impact)
  - Returns 0 if no terminated engines found
  - Cleanup is atomic and thread-safe

  """
  @spec clean_terminated_engines() :: non_neg_integer()
  def clean_terminated_engines do
    Services.clean_terminated_engines()
  end

  @doc """
  I check if an engine specification supports a specific message tag.

  ## Parameters

  - `name` - The engine type name
  - `version` - The engine type version (nil for latest)
  - `tag` - Message tag to check

  ## Returns

  - `{:ok, true}` if the tag exists
  - `{:ok, false}` if the tag does not exist
  - `{:error, :not_found}` if the spec is not found

  ## Examples

      # Check if an engine supports a message
      {:ok, true} = EngineSystem.API.has_message?(:my_engine, "1.0.0", :ping)
      {:ok, false} = EngineSystem.API.has_message?(:my_engine, "1.0.0", :unknown)
  """
  @spec has_message?(atom() | String.t(), String.t() | nil, atom()) ::
          {:ok, boolean()} | {:error, :not_found}
  def has_message?(name, version, tag) do
    case lookup_spec(name, version) do
      {:ok, spec} -> {:ok, Spec.has_message?(spec, tag)}
      {:error, :not_found} -> {:error, :not_found}
    end
  end

  @doc """
  I get the field specification for a message tag from an engine specification.

  ## Parameters

  - `name` - The engine type name
  - `version` - The engine type version (nil for latest)
  - `tag` - Message tag to find

  ## Returns

  - `{:ok, fields}` if found
  - `{:error, :not_found}` if not found (either spec or message tag)

  ## Examples

      # Get message fields for an engine
      {:ok, fields} = EngineSystem.API.get_message_fields(:my_engine, "1.0.0", :ping)
      {:error, :not_found} = EngineSystem.API.get_message_fields(:my_engine, "1.0.0", :unknown)
  """
  @spec get_message_fields(atom() | String.t(), String.t() | nil, atom()) ::
          {:ok, Spec.message_fields()} | {:error, :not_found}
  def get_message_fields(name, version, tag) do
    case lookup_spec(name, version) do
      {:ok, spec} -> Spec.get_message_fields(spec, tag)
      {:error, :not_found} -> {:error, :not_found}
    end
  end

  @doc """
  I get all message tags supported by an engine specification.

  ## Parameters

  - `name` - The engine type name
  - `version` - The engine type version (nil for latest)

  ## Returns

  - `{:ok, tags}` if found
  - `{:error, :not_found}` if not found

  ## Examples

      # Get message tags for an engine
      {:ok, tags} = EngineSystem.API.get_message_tags(:my_engine, "1.0.0")
  """
  @spec get_message_tags(atom() | String.t(), String.t() | nil) ::
          {:ok, [atom()]} | {:error, :not_found}
  def get_message_tags(name, version) do
    case lookup_spec(name, version) do
      {:ok, spec} -> {:ok, Spec.get_message_tags(spec)}
      {:error, :not_found} -> {:error, :not_found}
    end
  end

  @doc """
  I get all message tags supported by a running engine instance.

  ## Parameters

  - `address` - The engine's address

  ## Returns

  - `{:ok, tags}` if found
  - `{:error, :not_found}` if not found

  ## Examples

      # Get instance message tags
      {:ok, tags} = EngineSystem.API.get_instance_message_tags(target_address)
  """
  @spec get_instance_message_tags(State.address()) ::
          {:ok, [atom()]} | {:error, :not_found}
  def get_instance_message_tags(address) do
    case Registry.lookup_instance(address) do
      {:ok, instance_info} ->
        # Get the spec using the spec_key from instance_info
        {name, version} = instance_info.spec_key

        case Registry.lookup_spec(name, version) do
          {:ok, spec} -> {:ok, Spec.get_message_tags(spec)}
          {:error, :not_found} -> {:error, :not_found}
        end

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end
end
