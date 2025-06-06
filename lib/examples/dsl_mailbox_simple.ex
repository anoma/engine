defmodule Examples.DSLMailboxSimple do
  @moduledoc """
  Simple example showing how to define both processing engines and mailbox engines
  using the unified DSL.

  This demonstrates the CLEAN unified approach where:
  1. `mode :process` specifies it's a processing engine
  2. `mode :mailbox` specifies it's a mailbox engine
  3. Both use the same DSL syntax and patterns
  4. Developers implement their own policies in the `behaviour` block

  This is much cleaner and more architecturally consistent!
  """

  import EngineSystem.Engine.DSL

  # ============================================================================
  # PROCESSING ENGINE EXAMPLE
  # ============================================================================

  defengine KVProcessingEngine do
    @moduledoc "Example key-value processing engine using unified DSL."

    version("1.0.0")
    # This is a processing engine
    mode(:process)

    # Processing engine interface - what messages it can handle
    interface do
      message(:put, key: :atom, value: :any)
      message(:get, key: :atom)
      message(:delete, key: :atom)
      message(:clear_all)
      message(:list_keys)
      message(:get_stats)
      # Response messages
      message(:result, value: :any)
      message(:ack)
      message(:error, reason: :atom)
    end

    config do
      %{
        access_mode: :read_write,
        max_keys: 1000,
        enable_stats: true,
        auto_persist: false
      }
    end

    environment do
      %{
        store: %{},
        access_counts: %{},
        total_operations: 0,
        created_at: :erlang.system_time(:second)
      }
    end

    message_filter(fn _msg, _config, _env -> true end)

    # Processing engine behavior - the business logic
    behaviour do
      on_message :put, %{key: key, value: value}, config, env, sender do
        if map_size(env.store) >= config.max_keys and not Map.has_key?(env.store, key) do
          {:ok, [{:send, sender, {:error, :max_keys_reached}}]}
        else
          new_store = Map.put(env.store, key, value)

          new_access_counts =
            if config.enable_stats do
              Map.update(env.access_counts, key, 1, &(&1 + 1))
            else
              env.access_counts
            end

          new_env = %{
            env
            | store: new_store,
              access_counts: new_access_counts,
              total_operations: env.total_operations + 1
          }

          {:ok,
           [
             {:update_environment, new_env},
             {:send, sender, :ack}
           ]}
        end
      end

      on_message :get, %{key: key}, config, env, sender do
        value = Map.get(env.store, key)

        new_env =
          if config.enable_stats do
            new_access_counts = Map.update(env.access_counts, key, 1, &(&1 + 1))
            %{env | access_counts: new_access_counts, total_operations: env.total_operations + 1}
          else
            %{env | total_operations: env.total_operations + 1}
          end

        {:ok,
         [
           {:update_environment, new_env},
           {:send, sender, {:result, value}}
         ]}
      end

      on_message :delete, %{key: key}, _config, env, sender do
        if Map.has_key?(env.store, key) do
          new_store = Map.delete(env.store, key)
          new_access_counts = Map.delete(env.access_counts, key)

          new_env = %{
            env
            | store: new_store,
              access_counts: new_access_counts,
              total_operations: env.total_operations + 1
          }

          {:ok,
           [
             {:update_environment, new_env},
             {:send, sender, :ack}
           ]}
        else
          {:ok, [{:send, sender, {:error, :key_not_found}}]}
        end
      end

      on_message :clear_all, %{}, _config, env, sender do
        new_env = %{
          env
          | store: %{},
            access_counts: %{},
            total_operations: env.total_operations + 1
        }

        {:ok,
         [
           {:update_environment, new_env},
           {:send, sender, :ack}
         ]}
      end

      on_message :list_keys, %{}, _config, env, sender do
        keys = Map.keys(env.store)
        new_env = %{env | total_operations: env.total_operations + 1}

        {:ok,
         [
           {:update_environment, new_env},
           {:send, sender, {:result, keys}}
         ]}
      end

      on_message :get_stats, %{}, _config, env, sender do
        stats = %{
          total_keys: map_size(env.store),
          total_operations: env.total_operations,
          access_counts: env.access_counts,
          uptime_seconds: :erlang.system_time(:second) - env.created_at
        }

        {:ok, [{:send, sender, {:result, stats}}]}
      end
    end
  end

  # ============================================================================
  # SIMPLE FIFO MAILBOX ENGINE
  # ============================================================================

  defengine SimpleFIFOMailbox, compile: true do
    @moduledoc "Simple FIFO mailbox engine using unified DSL."

    version("1.0.0")
    # This is a mailbox engine
    mode(:mailbox)

    # Standard mailbox interface
    interface do
      message(:enqueue_message, message: :any)
      message(:request_batch, demand: :integer)
      message(:update_filter, filter: :function)
    end

    config do
      %{
        # Producer configuration moved to main config block
        producer_type: :demand_driven,
        max_demand: 100,
        min_demand: 10,
        batch_size: 10
      }
    end

    environment do
      %{
        message_queue: :queue.new(),
        current_demand: 0,
        total_received: 0,
        total_delivered: 0
      }
    end

    message_filter(fn _msg, _config, _env -> true end)

    # Implement simple FIFO delivery policy in behaviour
    behaviour do
      on_message :enqueue_message, %{message: message}, _config, env, _sender do
        new_queue = :queue.in(message, env.message_queue)
        new_env = %{env | message_queue: new_queue, total_received: env.total_received + 1}
        {:ok, [{:update_environment, new_env}]}
      end

      on_message :request_batch, %{demand: demand}, config, env, sender do
        batch_size = min(demand, config.batch_size)
        {messages, new_queue} = extract_messages(env.message_queue, batch_size, [])

        new_env = %{
          env
          | message_queue: new_queue,
            current_demand: env.current_demand + demand,
            total_delivered: env.total_delivered + length(messages)
        }

        {:ok,
         [
           {:update_environment, new_env},
           {:send, sender, {:deliver_batch, messages}}
         ]}
      end

      on_message :update_filter, %{filter: _new_filter}, _config, _env, sender do
        # Store filter in environment or forward to processing engine
        {:ok, [{:send, sender, :ack}]}
      end
    end

    # Helper function for message extraction (would be generated by compiler)
    defp extract_messages(queue, 0, acc), do: {Enum.reverse(acc), queue}

    defp extract_messages(queue, remaining, acc) do
      case :queue.out(queue) do
        {:empty, queue} ->
          {Enum.reverse(acc), queue}

        {{:value, message}, new_queue} ->
          extract_messages(new_queue, remaining - 1, [message | acc])
      end
    end
  end

  # ============================================================================
  # PRIORITY MAILBOX ENGINE
  # ============================================================================

  defengine PriorityMailbox do
    @moduledoc "Priority-based mailbox engine using unified DSL."

    version("1.0.0")
    mode(:mailbox)

    interface do
      message(:enqueue_message, message: :any)
      message(:request_batch, demand: :integer)
      message(:flush_coalesced_writes)
    end

    config do
      %{
        # Producer configuration moved to main config block
        producer_type: :demand_driven,
        max_demand: 50,
        min_demand: 5,
        batch_size: 8,
        coalesce_window_ms: 50
      }
    end

    environment do
      %{
        priority_buffer: :gb_trees.empty(),
        coalesce_buffer: %{},
        current_demand: 0,
        stats: %{received: 0, delivered: 0, coalesced: 0}
      }
    end

    message_filter(fn _msg, _config, _env -> true end)

    # Implement priority delivery + write coalescing in behaviour
    behaviour do
      on_message :enqueue_message, %{message: message}, _config, env, _sender do
        {category, priority} = categorize_message(message)

        case category do
          :write ->
            # Implement write coalescing
            key = extract_key(message)
            new_coalesce_buffer = Map.put(env.coalesce_buffer, key, message)
            new_stats = update_in(env.stats.received, &(&1 + 1))
            new_env = %{env | coalesce_buffer: new_coalesce_buffer, stats: new_stats}
            {:ok, [{:update_environment, new_env}]}

          _ ->
            # Add to priority buffer
            timestamp = :erlang.system_time(:microsecond)
            priority_key = {priority, timestamp, env.stats.received}
            new_buffer = :gb_trees.enter(priority_key, message, env.priority_buffer)
            new_stats = update_in(env.stats.received, &(&1 + 1))
            new_env = %{env | priority_buffer: new_buffer, stats: new_stats}
            {:ok, [{:update_environment, new_env}]}
        end
      end

      on_message :request_batch, %{demand: demand}, config, env, sender do
        # Extract messages by priority
        batch_size = min(demand, config.batch_size)
        {messages, new_buffer} = extract_priority_batch(env.priority_buffer, batch_size)

        new_stats = update_in(env.stats.delivered, &(&1 + length(messages)))

        new_env = %{
          env
          | priority_buffer: new_buffer,
            current_demand: env.current_demand + demand,
            stats: new_stats
        }

        {:ok,
         [
           {:update_environment, new_env},
           {:send, sender, {:deliver_batch, messages}}
         ]}
      end

      on_message :flush_coalesced_writes, %{}, _config, env, _sender do
        # Move coalesced writes to priority buffer
        coalesce_count = map_size(env.coalesce_buffer)

        new_buffer =
          Enum.reduce(env.coalesce_buffer, env.priority_buffer, fn {_key, message}, buffer ->
            timestamp = :erlang.system_time(:microsecond)
            # Write priority = 2
            priority_key = {2, timestamp, env.stats.received}
            :gb_trees.insert(priority_key, message, buffer)
          end)

        new_stats = update_in(env.stats.coalesced, &(&1 + coalesce_count))
        new_env = %{env | priority_buffer: new_buffer, coalesce_buffer: %{}, stats: new_stats}

        {:ok, [{:update_environment, new_env}]}
      end
    end

    # Helper functions (would be generated by compiler)
    defp categorize_message(message) do
      case message.payload do
        {:get, _} -> {:read, 1}
        {:put, _, _} -> {:write, 2}
        {:delete, _} -> {:delete, 3}
        _ -> {:other, 2}
      end
    end

    defp extract_key(message) do
      case message.payload do
        {:get, key} -> key
        {:put, key, _} -> key
        {:delete, key} -> key
        _ -> :unknown
      end
    end

    defp extract_priority_batch(buffer, batch_size) do
      extract_from_tree(buffer, batch_size, [])
    end

    defp extract_from_tree(buffer, 0, acc), do: {Enum.reverse(acc), buffer}

    defp extract_from_tree(buffer, remaining, acc) do
      if :gb_trees.is_empty(buffer) do
        {Enum.reverse(acc), buffer}
      else
        {_key, message, new_buffer} = :gb_trees.take_smallest(buffer)
        extract_from_tree(new_buffer, remaining - 1, [message | acc])
      end
    end
  end

  # ============================================================================
  # USAGE EXAMPLES - NEW UNIFIED APPROACH
  # ============================================================================

  @doc """
  Example usage showing both processing and mailbox engines using the same DSL.

  This demonstrates the architectural consistency achieved with the unified DSL approach.
  """
  def unified_example do
    # Both processing and mailbox engines use the same DSL syntax!

    # Spawn a processing engine with simple FIFO mailbox
    {:ok, addr1} =
      EngineSystem.spawn_engine(
        # Processing engine (DSL-defined)
        KVProcessingEngine,
        # Processing config
        %{access_mode: :read_write},
        # Processing environment
        %{store: %{}},
        # Name
        :kv_with_fifo,
        # Mailbox engine (ALSO DSL-defined!)
        SimpleFIFOMailbox,
        # Mailbox config
        %{batch_size: 10}
      )

    # Spawn the same processing engine with priority mailbox
    {:ok, addr2} =
      EngineSystem.spawn_engine(
        # Same processing engine
        KVProcessingEngine,
        %{access_mode: :read_write},
        %{store: %{}},
        :kv_with_priority,
        # Different mailbox engine (ALSO DSL-defined!)
        PriorityMailbox,
        %{batch_size: 8, coalesce_window_ms: 50}
      )

    %{fifo: addr1, priority: addr2}
  end

  @doc """
  Example showing how to spawn a standalone mailbox engine.

  Mailbox engines can operate independently as message brokers/queues.
  """
  def standalone_mailbox_example do
    # Mailbox engines can run independently!
    {:ok, mailbox_addr} =
      EngineSystem.spawn_engine(
        # This is a mailbox engine
        SimpleFIFOMailbox,
        # Configuration
        %{batch_size: 20, max_demand: 200},
        # Environment
        %{},
        # Name
        :standalone_queue
      )

    mailbox_addr
  end

  @doc """
  Demonstration of sending messages and checking results.
  """
  def demo_workflow do
    # Spawn engines
    addresses = unified_example()
    fifo_addr = addresses.fifo
    priority_addr = addresses.priority

    # Send some messages to the FIFO-backed engine
    :ok = EngineSystem.send_message(fifo_addr, {:put, %{key: :user1, value: "Alice"}})
    :ok = EngineSystem.send_message(fifo_addr, {:put, %{key: :user2, value: "Bob"}})
    :ok = EngineSystem.send_message(fifo_addr, {:get, %{key: :user1}})
    :ok = EngineSystem.send_message(fifo_addr, {:get_stats, %{}})

    # Send some messages to the priority-backed engine
    :ok = EngineSystem.send_message(priority_addr, {:put, %{key: :admin, value: "Admin User"}})
    :ok = EngineSystem.send_message(priority_addr, {:list_keys, %{}})

    # Both engines have the same processing logic but different message delivery!
    %{
      message: "Messages sent to both engines - check their behavior!",
      engines: addresses
    }
  end

  @doc """
  Show stats comparing different mailbox behaviors.
  """
  def compare_mailbox_stats do
    addresses = unified_example()

    # Get instance information
    {:ok, fifo_info} = EngineSystem.lookup_instance(addresses.fifo)
    {:ok, priority_info} = EngineSystem.lookup_instance(addresses.priority)

    %{
      fifo_engine: %{
        address: addresses.fifo,
        mailbox_pid: fifo_info.mailbox_pid,
        spec: fifo_info.spec_key
      },
      priority_engine: %{
        address: addresses.priority,
        mailbox_pid: priority_info.mailbox_pid,
        spec: priority_info.spec_key
      },
      architecture:
        "Both engines use the same processing logic with different mailbox delivery policies!"
    }
  end
end
