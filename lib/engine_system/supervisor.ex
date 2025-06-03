defmodule EngineSystem.Supervisor do
  @moduledoc """
  I am the root supervisor for the OTP application.

  I provide fault tolerance and lifecycle management for the EngineSystem by
  supervising critical components and ensuring they can recover from failures.
  I form the foundation of the system's reliability and resilience.

  ## Supervision Strategy

  I use a `:one_for_one` strategy, meaning if any supervised process fails,
  only that process is restarted without affecting others.

  ## Supervised Components

  I supervise these critical system components:

  1. **System Registry** (`EngineSystem.System.Registry`) - Central registry for
     engine specifications and instance tracking
  2. **Engine Dynamic Supervisor** - Manages individual engine instances
  3. **Mailbox Dynamic Supervisor** - Manages mailbox engine instances

  ## Fault Tolerance

  I ensure the system can recover from various failure scenarios:
  - Registry crashes are handled with automatic restart
  - Dynamic supervisors are recreated if they fail
  - Each component can restart independently

  ## System Health

  I maintain system health by:
  - Monitoring critical processes
  - Restarting failed components
  - Preserving system state where possible
  - Providing fault isolation

  ## Public API

  - `start_link/1` - Start the supervisor (typically called by Application)

  ## Examples

      # Manual supervisor start (typically done by Application)
      {:ok, pid} = EngineSystem.Supervisor.start_link([])

      # Check supervisor status
      children = Supervisor.which_children(EngineSystem.Supervisor)
      IO.puts("Supervised processes: \#{length(children)}")

      # Monitor supervisor health
      def check_supervisor_health do
        case Process.whereis(EngineSystem.Supervisor) do
          nil ->
            IO.puts("❌ EngineSystem.Supervisor not running")
            {:error, :not_running}

          pid when is_pid(pid) ->
            children = Supervisor.which_children(pid)
            running_children = Enum.count(children, fn {_id, child_pid, _type, _modules} ->
              is_pid(child_pid)
            end)

            IO.puts("✅ EngineSystem.Supervisor running")
            IO.puts("   PID: \#{inspect(pid)}")
            IO.puts("   Active children: \#{running_children}/\#{length(children)}")

            {:ok, %{supervisor_pid: pid, children_count: length(children), running_count: running_children}}
        end
      end

      # Get detailed supervisor information
      def supervisor_info do
        pid = Process.whereis(EngineSystem.Supervisor)
        if pid do
          children = Supervisor.which_children(pid)

          info = %{
            supervisor_pid: pid,
            strategy: :one_for_one,
            children: Enum.map(children, fn {id, child_pid, type, modules} ->
              %{
                id: id,
                pid: child_pid,
                type: type,
                modules: modules,
                status: if(is_pid(child_pid), do: :running, else: :not_running)
              }
            end)
          }

          IO.puts("📋 Supervisor Information:")
          IO.puts("  PID: \#{inspect(info.supervisor_pid)}")
          IO.puts("  Strategy: \#{info.strategy}")
          IO.puts("  Children:")

          Enum.each(info.children, fn child ->
            status_icon = if child.status == :running, do: "✅", else: "❌"
            IO.puts("    \#{status_icon} \#{child.id} - \#{inspect(child.pid)}")
          end)

          info
        else
          IO.puts("❌ Supervisor not running")
          {:error, :not_running}
        end
      end

  ## Notes

  - I am automatically started when the EngineSystem application starts
  - All supervised processes are essential for system operation
  - If I crash, the entire EngineSystem will restart
  - Dynamic supervisors allow for flexible engine management
  - Registry is the most critical component I supervise

  """

  use Supervisor

  alias EngineSystem.System.Registry

  @doc """
  I start the supervisor with the given initialization arguments.

  This is typically called automatically by the EngineSystem application
  when it starts up.

  ## Parameters

  - `init_arg` - Initialization arguments (usually an empty list)

  ## Returns

  - `{:ok, pid}` if the supervisor started successfully
  - `{:error, reason}` if startup failed

  ## Examples

      # Automatic start via Application
      # (This happens when EngineSystem.start() is called)

      # Manual start (advanced usage)
      {:ok, supervisor_pid} = EngineSystem.Supervisor.start_link([])

      # Verify supervisor is running
      children = Supervisor.which_children(supervisor_pid)
      IO.puts("Started supervisor with \#{length(children)} children")

  """
  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      # System Registry - tracks engine specs and instances
      {Registry, name: EngineSystem.System.Registry},

      # Dynamic Supervisor for Engine Instances
      {DynamicSupervisor, name: EngineSystem.Engine.DynamicSupervisor, strategy: :one_for_one},

      # Dynamic Supervisor for Mailbox Engines
      {DynamicSupervisor, name: EngineSystem.Mailbox.DynamicSupervisor, strategy: :one_for_one}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
