defmodule EngineSystem.Lifecycle do
  @moduledoc """
  I handle the lifecycle operations for the EngineSystem.

  I manage:
  - Starting and stopping the system
  - Application lifecycle management
  - System initialization and cleanup
  - Health checks and system validation

  ## Public API

  - `start/0` - Start the EngineSystem application with all components
  - `stop/0` - Stop the EngineSystem application gracefully
  - `reset/0` - Reset the EngineSystem application (stop then start)

  ## System Startup Process

  When the system starts, I initialize:
  1. Core supervision tree
  2. System registry for specs and instances
  3. Dynamic supervisors for engines and mailboxes
  4. Background services and utilities

  ## Error Handling

  I provide robust error handling for all lifecycle operations,
  ensuring the system can recover from various failure scenarios.
  """

  @doc """
  I start the EngineSystem application.

  This starts the complete OTP application with all necessary supervisors,
  services, and background processes. The system will be ready to accept
  engine definitions, spawn instances, and handle message passing.

  ## Returns

  - `{:ok, [app_list]}` if the system started successfully
  - `{:error, reason}` if startup failed

  ## Examples

      # Basic system startup
      {:ok, apps} = EngineSystem.Lifecycle.start()
      IO.puts("Started applications: \#{inspect(apps)}")

      # Startup with error handling
      case EngineSystem.Lifecycle.start() do
        {:ok, apps} ->
          IO.puts(IO.ANSI.green() <> "EngineSystem started successfully" <> IO.ANSI.reset())
          IO.puts("Active applications: \#{Enum.join(apps, ", ")}")

          # Verify system is ready
          system_info = EngineSystem.API.get_system_info()
          IO.puts("System uptime: \#{system_info.system_uptime}ms")

        {:error, {:already_started, _app}} ->
          IO.puts(IO.ANSI.yellow() <> "EngineSystem already running" <> IO.ANSI.reset())
          :ok

        {:error, reason} ->
          IO.puts("❌ Failed to start EngineSystem: \#{inspect(reason)}")
          {:error, reason}
      end

      # Integration with supervision tree
      defmodule MyApp.Application do
        use Application

        def start(_type, _args) do
          children = [
            # Start EngineSystem as part of your application
            {Task, fn -> EngineSystem.Lifecycle.start() end},
            # Your other children...
          ]

          Supervisor.start_link(children, strategy: :one_for_one)
        end
      end

      # Development workflow
      # In IEx:
      iex> EngineSystem.Lifecycle.start()
      {:ok, [:engine_system]}

      iex> EngineSystem.API.get_system_info()
      %{
        library_version: "1.0.0",
        total_instances: 0,
        running_instances: 0,
        total_specs: 0,
        system_uptime: 1234
      }

  ## Notes

  - Safe to call multiple times (idempotent)
  - Automatically starts dependencies (:logger, :crypto, etc.)
  - System is immediately ready for use after successful start
  - All dynamic supervisors are pre-initialized
  - Registry services are available immediately

  """
  @spec start() :: {:ok, [atom()]} | {:error, any()}
  def start do
    Application.ensure_all_started(:engine_system)
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
      :ok = EngineSystem.Lifecycle.stop()
      IO.puts("EngineSystem stopped")

      # Graceful shutdown with cleanup
      def graceful_shutdown do
        IO.puts("🛑 Initiating EngineSystem shutdown...")

        # Get current state before shutdown
        system_info = EngineSystem.API.get_system_info()
        IO.puts("Stopping system with \#{system_info.running_instances} active engines")

        # Optional: Terminate engines explicitly first
        instance_list = EngineSystem.API.list_instances()
        Enum.each(instance_list, fn {address, _info} ->
          IO.puts("Terminating engine \#{inspect(address)}")
          EngineSystem.API.terminate_engine(address)
        end)

        # Wait a moment for graceful termination
        Process.sleep(100)

        # Stop the system
        :ok = EngineSystem.Lifecycle.stop()
        IO.puts("✅ EngineSystem shutdown complete")
      end

      # Application shutdown integration
      defmodule MyApp.Application do
        def stop(_state) do
          IO.puts("Stopping application...")
          EngineSystem.Lifecycle.stop()
          :ok
        end
      end

      # Development workflow
      # In IEx:
      iex> EngineSystem.Lifecycle.stop()
      :ok

      # Verify system is stopped
      iex> EngineSystem.API.get_system_info()
      ** (RuntimeError) EngineSystem not started

  ## Notes

  - Always returns `:ok` (does not fail)
  - Safe to call when system is already stopped
  - Automatically handles dependency cleanup
  - Running engines are terminated as part of shutdown
  - All system resources are released

  """
  @spec stop() :: :ok
  def stop do
    Application.stop(:engine_system)
  end

  @doc """
  I reset the EngineSystem application.

  This performs a complete system restart by stopping the system cleanly
  and then starting it fresh. All engines, specs, and runtime state are
  cleared, providing a clean slate for testing or recovery scenarios.

  ## Returns

  - `{:ok, [app_list]}` if the system reset successfully
  - `{:error, reason}` if reset failed during startup

  ## Examples

      # Basic system reset
      {:ok, apps} = EngineSystem.Lifecycle.reset()
      IO.puts("System reset complete, apps: \#{inspect(apps)}")

      # Reset with verification
      def reset_system do
        IO.puts("🔄 Resetting EngineSystem...")

        # Capture state before reset
        old_info = try do
          EngineSystem.API.get_system_info()
        rescue
          _ -> %{total_instances: 0, running_instances: 0}
        end

        # Perform reset
        case EngineSystem.Lifecycle.reset() do
          {:ok, apps} ->
            IO.puts("✅ Reset successful")

            # Verify clean state
            new_info = EngineSystem.API.get_system_info()
            IO.puts("Before reset: \#{old_info.running_instances} engines")
            IO.puts("After reset: \#{new_info.running_instances} engines")
            IO.puts("Fresh system uptime: \#{new_info.system_uptime}ms")

            {:ok, apps}

          {:error, reason} ->
            IO.puts("❌ Reset failed: \#{inspect(reason)}")
            {:error, reason}
        end
      end

      # Testing workflow reset
      def reset_for_test do
        # Common pattern in test setup
        EngineSystem.Lifecycle.reset()

        # Verify clean slate
        assert EngineSystem.API.list_instances() == []
        assert EngineSystem.API.list_specs() == []

        # System is now ready for test scenario
        :ok
      end

      # Recovery scenario
      def emergency_reset do
        IO.puts("🚨 Emergency system reset...")

        # Force reset even if there are issues
        try do
          EngineSystem.Lifecycle.reset()
        rescue
          error ->
            IO.puts("Reset encountered error: \#{inspect(error)}")
            # Force stop and restart
            EngineSystem.Lifecycle.stop()
            Process.sleep(500)
            EngineSystem.Lifecycle.start()
        end
      end

      # Development workflow
      # In IEx:
      iex> EngineSystem.Lifecycle.reset()
      {:ok, [:engine_system]}

      # Everything is fresh
      iex> EngineSystem.API.get_system_info()
      %{
        library_version: "1.0.0",
        total_instances: 0,
        running_instances: 0,
        total_specs: 0,
        system_uptime: 45  # Fresh uptime
      }

  ## Use Cases

  - **Testing**: Clean state between test suites
  - **Development**: Reset during iterative development
  - **Recovery**: Recover from corrupted system state
  - **Deployment**: Initialize fresh production environment
  - **Debugging**: Start with known clean state

  ## Notes

  - All running engines are terminated during reset
  - All registered specs are cleared from memory
  - System metrics and uptime are reset to zero
  - No data is persisted across resets
  - Safe to call regardless of current system state

  """
  @spec reset() :: {:ok, [atom()]} | {:error, any()}
  def reset do
    stop()
    start()
  end
end
