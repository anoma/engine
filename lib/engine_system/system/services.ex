defmodule EngineSystem.System.Services do
  @moduledoc """
  I provide miscellaneous system-wide services and functions.

  This module implements system services like unique identifier generation
  and mailbox address lookup as specified in the formal model.

  ## Public API

  ### System Services
  - `fresh_id/0` - Generate a unique identifier for engine instances, messages, etc.
  - `mailbox_of_name/1` - Get the mailbox address for a given processing engine
  - `send_message/2` - Send a message to an engine (convenience function)
  - `get_system_info/0` - Get system-wide information and statistics

  ### Node Management
  - `create_node/1` - Create a new node in the system
  - `current_node_id/0` - Get the current node ID

  ### Validation and Cleanup
  - `validate_message/2` - Validate that a message conforms to an engine's interface
  - `clean_terminated_engines/0` - Clean up terminated engines from the system
  """

  alias EngineSystem.Engine.State
  alias EngineSystem.System.Registry

  @doc """
  I generate a unique identifier for engine instances, messages, etc.

  This implements the `freshid` function from the formal model.

  ## Returns

  A unique integer identifier.
  """
  @spec fresh_id() :: non_neg_integer()
  def fresh_id do
    Registry.fresh_id()
  end

  @doc """
  I get the mailbox address for a given processing engine.

  This implements the `mailboxOfname` function from the formal model.
  Every processing engine has an associated mailbox engine that handles
  message queuing and delivery.

  ## Parameters

  - `engine_address` - The address of the processing engine (tuple of {node_id, engine_id})

  ## Returns

  - `{:ok, mailbox_address}` if the mailbox is found
  - `{:error, :not_found}` if the engine doesn't exist
  - `{:error, :no_mailbox}` if the engine exists but has no mailbox

  ## Examples

      # Get mailbox for a running engine
      {:ok, engine_addr} = EngineSystem.API.spawn_engine(MyEngine)
      {:ok, mailbox_addr} = EngineSystem.System.Services.mailbox_of_name(engine_addr)

      # Use the mailbox address for direct communication
      message = EngineSystem.System.Message.new({0, 0}, mailbox_addr, {:ping, %{}})
      :ok = EngineSystem.System.Services.send_message(mailbox_addr, message)

      # Handle cases where engine doesn't exist
      case EngineSystem.System.Services.mailbox_of_name({999, 999}) do
        {:ok, mailbox_addr} ->
          IO.puts("Found mailbox: \#{inspect(mailbox_addr)}")
        {:error, :not_found} ->
          IO.puts("Engine not found")
        {:error, :no_mailbox} ->
          IO.puts("Engine has no mailbox")
      end

      # Typical usage in engine communication
      defmodule MyProcessingEngine do
        def send_to_peer(peer_address, message) do
          case EngineSystem.System.Services.mailbox_of_name(peer_address) do
            {:ok, mailbox_addr} ->
              EngineSystem.System.Services.send_message(mailbox_addr, message)
            {:error, reason} ->
              {:error, {:cannot_reach_peer, reason}}
          end
        end
      end

  """
  @spec mailbox_of_name(State.address()) :: {:ok, State.address()} | {:error, :not_found}
  def mailbox_of_name(engine_address) do
    case Registry.lookup_instance(engine_address) do
      {:ok, %{mailbox_pid: mailbox_pid}} when not is_nil(mailbox_pid) ->
        # For now, we'll construct the mailbox address based on the engine address
        # In a full implementation, this would be properly tracked
        {node_id, engine_id} = engine_address
        # Simple offset for demo
        mailbox_address = {node_id, engine_id + 1000}
        {:ok, mailbox_address}

      {:ok, %{mailbox_pid: nil}} ->
        {:error, :no_mailbox}

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end

  @doc """
  I send a message to an engine.

  This is a convenience function that handles message routing to the appropriate
  mailbox engine.

  ## Parameters

  - `target_address` - The address of the target engine
  - `message` - The message to send

  ## Returns

  - `:ok` if the message was sent successfully
  - `{:error, reason}` if sending failed
  """
  @spec send_message(State.address(), any()) :: :ok | {:error, :not_found}
  def send_message(target_address, message) do
    case Registry.lookup_instance(target_address) do
      {:ok, %{mailbox_pid: mailbox_pid}} when not is_nil(mailbox_pid) ->
        # Send the message to the mailbox engine using the MailboxRuntime
        if Process.alive?(mailbox_pid) do
          EngineSystem.Mailbox.MailboxRuntime.enqueue_message(mailbox_pid, message)
          :ok
        else
          {:error, :mailbox_down}
        end

      {:ok, %{mailbox_pid: nil}} ->
        # Engine has no mailbox, send directly to the engine process
        case Registry.lookup_instance(target_address) do
          {:ok, %{engine_pid: engine_pid}} ->
            # Extract message parts
            {message_tag, payload} =
              case message.payload do
                {tag, p} -> {tag, p}
                tag when is_atom(tag) -> {tag, %{}}
                other -> {:unknown, other}
              end

            # Send directly to engine using GenServer call
            GenServer.cast(engine_pid, {:message, message_tag, payload, message.sender})
            :ok

          {:error, _} ->
            {:error, :engine_not_found}
        end

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end

  @doc """
  I create a new node in the system.

  This implements node creation as specified in the s-Node rule from the
  formal model. I prepare the infrastructure for distributed engine
  management and communication.

  ## Parameters

  - `node_plugins` - Optional plugins/services for the node (default: %{})

  ## Returns

  - `{:ok, node_id}` if the node was created successfully
  - `{:error, reason}` if creation failed

  ## Examples

      # Basic node creation
      {:ok, node_id} = EngineSystem.System.Services.create_node()
      IO.puts("Created node with ID: \#{node_id}")

      # Node creation with plugins
      plugins = %{
        logging: true,
        monitoring: %{enabled: true, interval: 30_000},
        persistence: %{type: :memory}
      }
      {:ok, node_id} = EngineSystem.System.Services.create_node(plugins)

      # Distributed system node setup
      def setup_distributed_node(node_config) do
        plugins = %{
          cluster_id: node_config.cluster_id,
          replication: node_config.replication_settings,
          network: node_config.network_config
        }

        case EngineSystem.System.Services.create_node(plugins) do
          {:ok, node_id} ->
            IO.puts("✅ Node \#{node_id} joined cluster \#{plugins.cluster_id}")
            register_node_with_cluster(node_id, plugins)
            {:ok, node_id}

          {:error, reason} ->
            IO.puts("❌ Failed to create node: \#{inspect(reason)}")
            {:error, reason}
        end
      end

  ## Notes

  - In a full distributed implementation, this manages actual nodes
  - Currently returns a unique ID for single-node development
  - Plugins parameter is reserved for future distributed features
  - Node IDs are unique across the entire system

  """
  @spec create_node(map()) :: {:ok, non_neg_integer()}
  def create_node(_node_plugins \\ %{}) do
    node_id = fresh_id()

    # In a full implementation, this would:
    # 1. Create the node structure
    # 2. Initialize node-specific services
    # 3. Register the node in the system

    {:ok, node_id}
  end

  @doc """
  I get system-wide information and statistics.

  I collect comprehensive metrics about the current state of the EngineSystem,
  providing insights into system health, resource usage, and operational status.

  ## Returns

  A map containing detailed system information:
  - `library_version` - Version of the EngineSystem library
  - `total_instances` - Total number of engine instances ever created
  - `running_instances` - Number of currently active engines
  - `total_specs` - Number of registered engine specifications
  - `system_uptime` - Time since system startup in milliseconds

  ## Examples

      # Basic system information
      info = EngineSystem.System.Services.get_system_info()
      IO.puts("System has \#{info.running_instances} running engines")

      # Detailed system health check
      def system_health_check do
        info = EngineSystem.System.Services.get_system_info()

        IO.puts("🔍 EngineSystem Health Report")
        IO.puts("================================")
        IO.puts("Library Version: \#{info.library_version}")
        IO.puts("System Uptime: \#{info.system_uptime}ms (\#{info.system_uptime / 1000}s)")
        IO.puts("Total Engines: \#{info.total_instances}")
        IO.puts("Running Engines: \#{info.running_instances}")
        IO.puts("Terminated Engines: \#{info.total_instances - info.running_instances}")
        IO.puts("Registered Specs: \#{info.total_specs}")

        # Calculate health metrics
        termination_rate = if info.total_instances > 0 do
          (info.total_instances - info.running_instances) / info.total_instances * 100
        else
          0
        end

        health_status = cond do
          info.running_instances == 0 and info.total_instances > 0 -> "❌ CRITICAL"
          termination_rate > 50 -> "⚠️  WARNING"
          termination_rate > 20 -> "🔶 CAUTION"
          true -> "✅ HEALTHY"
        end

        IO.puts("System Status: \#{health_status}")
        IO.puts("Termination Rate: \#{Float.round(termination_rate, 1)}%")

        %{info | health_status: health_status, termination_rate: termination_rate}
      end

      # Monitoring dashboard data
      def dashboard_metrics do
        info = EngineSystem.System.Services.get_system_info()

        metrics = %{
          timestamp: DateTime.utc_now(),
          engines: %{
            total: info.total_instances,
            running: info.running_instances,
            terminated: info.total_instances - info.running_instances
          },
          specs: %{
            registered: info.total_specs
          },
          system: %{
            version: info.library_version,
            uptime_ms: info.system_uptime,
            uptime_hours: info.system_uptime / (1000 * 60 * 60)
          }
        }

        IO.puts("📊 Dashboard Metrics (\#{metrics.timestamp})")
        IO.puts("  Engines: \#{metrics.engines.running}/\#{metrics.engines.total} running")
        IO.puts("  Specs: \#{metrics.specs.registered} registered")
        IO.puts("  Uptime: \#{Float.round(metrics.system.uptime_hours, 2)} hours")

        metrics
      end

      # Performance monitoring
      def performance_check do
        start_time = :erlang.system_time(:millisecond)
        info = EngineSystem.System.Services.get_system_info()
        end_time = :erlang.system_time(:millisecond)

        query_time = end_time - start_time

        performance = %{
          info: info,
          query_time_ms: query_time,
          engines_per_ms: if(query_time > 0, do: info.total_instances / query_time, else: 0)
        }

        IO.puts("⚡ Performance Metrics:")
        IO.puts("  Query Time: \#{query_time}ms")
        IO.puts("  Throughput: \#{Float.round(performance.engines_per_ms, 2)} engines/ms")

        performance
      end

  ## Use Cases

  - **System Monitoring**: Track overall system health and performance
  - **Dashboard Displays**: Provide real-time system metrics
  - **Alerting**: Trigger alerts based on system state
  - **Capacity Planning**: Monitor resource usage trends
  - **Debugging**: Understand system state during troubleshooting

  ## Notes

  - Information is collected at call time (not cached)
  - System uptime resets when EngineSystem is restarted
  - Terminated engines are included in total count
  - Performance impact is minimal for regular monitoring
  - All metrics are computed from current registry state

  """
  @spec get_system_info() :: %{
          library_version: any(),
          running_instances: non_neg_integer(),
          system_uptime: integer(),
          total_instances: non_neg_integer(),
          total_specs: non_neg_integer()
        }
  def get_system_info do
    instances = Registry.list_instances()
    specs = Registry.list_specs()

    %{
      total_instances: length(instances),
      total_specs: length(specs),
      running_instances: Enum.count(instances, fn info -> info.status == :running end),
      system_uptime: :erlang.system_time(:millisecond),
      library_version: Application.spec(:engine_system, :vsn) || "unknown"
    }
  end

  @doc """
  I validate that a message conforms to an engine's interface.

  I check whether a message payload matches the expected interface
  specification for a target engine, ensuring type safety and
  preventing runtime errors from invalid messages.

  ## Parameters

  - `engine_address` - The target engine's address
  - `message` - The message payload to validate

  ## Returns

  - `:ok` if the message is valid for the target engine
  - `{:error, :engine_not_found}` if the engine doesn't exist
  - `{:error, :spec_not_found}` if the engine's spec isn't found
  - `{:error, {:unknown_message_tag, tag}}` if the message tag isn't supported

  ## Examples

      # Basic message validation
      case EngineSystem.System.Services.validate_message(engine_addr, {:ping, %{}}) do
        :ok ->
          IO.puts("✅ Message is valid")
          EngineSystem.API.send_message(engine_addr, {:ping, %{}})
        {:error, reason} ->
          IO.puts("❌ Invalid message: \#{inspect(reason)}")
      end

      # Validation before sending
      def safe_send_message(target_addr, message) do
        case EngineSystem.System.Services.validate_message(target_addr, message) do
          :ok ->
            EngineSystem.API.send_message(target_addr, message)

          {:error, :engine_not_found} ->
            IO.puts("❌ Target engine not found: \#{inspect(target_addr)}")
            {:error, :target_not_found}

          {:error, :spec_not_found} ->
            IO.puts("❌ Engine spec not found for \#{inspect(target_addr)}")
            {:error, :invalid_engine}

          {:error, {:unknown_message_tag, tag}} ->
            IO.puts("❌ Engine doesn't support message tag: \#{tag}")
            {:error, {:unsupported_message, tag}}
        end
      end

      # Batch message validation
      def validate_message_batch(engine_addr, messages) do
        results = Enum.map(messages, fn message ->
          {message, EngineSystem.System.Services.validate_message(engine_addr, message)}
        end)

        {valid, invalid} = Enum.split_with(results, fn {_msg, result} -> result == :ok end)

        IO.puts("📊 Validation Results:")
        IO.puts("  Valid: \#{length(valid)} messages")
        IO.puts("  Invalid: \#{length(invalid)} messages")

        if length(invalid) > 0 do
          IO.puts("❌ Invalid messages:")
          Enum.each(invalid, fn {msg, error} ->
            IO.puts("    \#{inspect(msg)} -> \#{inspect(error)}")
          end)
        end

        %{
          valid: Enum.map(valid, fn {msg, _} -> msg end),
          invalid: Enum.map(invalid, fn {msg, error} -> {msg, error} end),
          total: length(messages),
          success_rate: length(valid) / length(messages) * 100
        }
      end

      # Interface compatibility check
      def check_interface_compatibility(engine_addr, required_messages) do
        compatibility = Enum.map(required_messages, fn message_tag ->
          test_message = {message_tag, %{}}
          result = EngineSystem.System.Services.validate_message(engine_addr, test_message)
          {message_tag, result == :ok}
        end)

        supported = Enum.filter(compatibility, fn {_tag, supported} -> supported end)
        unsupported = Enum.filter(compatibility, fn {_tag, supported} -> !supported end)

        IO.puts("🔌 Interface Compatibility:")
        IO.puts("  Supported: \#{Enum.map(supported, fn {tag, _} -> tag end) |> inspect}")
        IO.puts("  Unsupported: \#{Enum.map(unsupported, fn {tag, _} -> tag end) |> inspect}")

        %{
          supported: Enum.map(supported, fn {tag, _} -> tag end),
          unsupported: Enum.map(unsupported, fn {tag, _} -> tag end),
          compatibility_rate: length(supported) / length(required_messages) * 100
        }
      end

  ## Use Cases

  - **Type Safety**: Prevent runtime errors from invalid messages
  - **API Validation**: Ensure client messages conform to engine interfaces
  - **Testing**: Validate test messages before sending
  - **Integration**: Check compatibility between engine types
  - **Debugging**: Understand why messages might be rejected

  ## Notes

  - Validation is performed against the engine's registered specification
  - Only checks message structure, not business logic validity
  - Fast operation suitable for runtime validation
  - Does not validate message payload data types (only tags)
  - Engine must be running and registered for validation to work

  """
  @spec validate_message(State.address(), any()) ::
          :ok | {:error, :engine_not_found | :spec_not_found | {:unknown_message_tag, any()}}
  def validate_message(engine_address, message) do
    case Registry.lookup_instance(engine_address) do
      {:ok, %{spec_key: spec_key}} ->
        case Registry.lookup_spec(elem(spec_key, 0), elem(spec_key, 1)) do
          {:ok, spec} ->
            EngineSystem.Engine.Spec.validate_message(spec, message)

          {:error, :not_found} ->
            {:error, :spec_not_found}
        end

      {:error, :not_found} ->
        {:error, :engine_not_found}
    end
  end

  @doc """
  I clean up terminated engines from the system.

  This implements the s-Clean rule from the formal model.

  ## Returns

  The number of engines that were cleaned up.
  """
  @spec clean_terminated_engines() :: non_neg_integer()
  def clean_terminated_engines do
    instances = Registry.list_instances()

    terminated_count =
      instances
      |> Enum.filter(fn info -> info.status == :terminated end)
      |> Enum.map(fn info ->
        Registry.unregister_instance(info.address)
        info
      end)
      |> length()

    terminated_count
  end

  @doc """
  I get the current node ID.

  For now, this returns a default node ID since we're running on a single node.

  ## Returns

  The current node ID.
  """
  @spec current_node_id() :: 1
  def current_node_id do
    # In a distributed system, this would return the actual node ID
    # For now, we use a default value
    1
  end

  @doc """
  I generate a unique address for a new engine.

  ## Returns

  A new unique address tuple.
  """
  @spec generate_address() :: State.address()
  def generate_address do
    node_id = current_node_id()
    engine_id = fresh_id()
    {node_id, engine_id}
  end
end
