defmodule Examples.CustomMailboxUsage do
  @moduledoc """
  Examples demonstrating how to use custom mailbox engines with key-value stores.

  This module shows practical usage patterns for the two custom mailbox engines:
  - KVPriorityMailboxEngine: Priority-based buffering with write coalescing
  - KVAdaptiveMailboxEngine: Adaptive load balancing with pattern recognition
  """

  alias EngineSystem.Mailbox.{KVPriorityMailboxEngine, KVAdaptiveMailboxEngine}
  alias Examples.KVStoreEngine

  @doc """
  Example 1: Basic usage with priority-based mailbox engine.
  """
  def example_priority_mailbox do
    # Spawn a KV store with priority-based mailbox engine
    {:ok, address} =
      EngineSystem.spawn_engine(
        # Processing engine
        KVStoreEngine,
        # Processing engine config
        %{access_mode: :read_write},
        # Processing engine environment
        %{store: %{}},
        # Name
        :priority_kv_store,
        # Mailbox engine
        KVPriorityMailboxEngine,
        # Mailbox engine config
        %{
          max_buffer_size: 2000,
          batch_size: 15,
          coalesce_window_ms: 100
        }
      )

    # Send some messages to demonstrate priority handling
    :ok = EngineSystem.send_message(address, {:put, :key1, :value1})
    # Will be coalesced
    :ok = EngineSystem.send_message(address, {:put, :key1, :value2})
    # Higher priority
    :ok = EngineSystem.send_message(address, {:get, :key1})

    # The GET message will be delivered before the coalesced PUT

    {:ok, address}
  end

  @doc """
  Example 2: Advanced usage with adaptive mailbox engine.
  """
  def example_adaptive_mailbox do
    # Spawn a KV store with adaptive mailbox engine
    {:ok, address} =
      EngineSystem.spawn_engine_with_mailbox(
        processing_engine: KVStoreEngine,
        processing_config: %{access_mode: :read_write, max_size: 10000},
        processing_env: %{store: %{}, access_counts: %{}},
        mailbox_engine: KVAdaptiveMailboxEngine,
        mailbox_config: %{
          initial_buffer_size: 1000,
          min_buffer_size: 200,
          max_buffer_size: 8000,
          adaptation_window_ms: 500
        },
        name: :adaptive_kv_store
      )

    # Send burst of messages to trigger adaptation
    for i <- 1..100 do
      :ok = EngineSystem.send_message(address, {:put, "key_#{rem(i, 10)}", "value_#{i}"})
    end

    # Send read requests for hot keys
    for i <- 1..50 do
      # Creates hot keys
      :ok = EngineSystem.send_message(address, {:get, "key_#{rem(i, 3)}"})
    end

    # The adaptive engine will:
    # 1. Detect hot keys (key_0, key_1, key_2)
    # 2. Adapt buffer size based on load
    # 3. Adjust batch size for optimal throughput
    # 4. Apply congestion control if needed

    {:ok, address}
  end

  @doc """
  Example 3: Comparing performance between different mailbox engines.
  """
  def example_performance_comparison do
    # Spawn same processing engine with different mailbox engines
    {:ok, default_address} =
      EngineSystem.spawn_engine(
        KVStoreEngine,
        %{},
        %{store: %{}},
        :default_kv
        # Uses DefaultMailboxEngine by default
      )

    {:ok, priority_address} =
      EngineSystem.spawn_engine(
        KVStoreEngine,
        %{},
        %{store: %{}},
        :priority_kv,
        KVPriorityMailboxEngine,
        %{max_buffer_size: 1000, batch_size: 10}
      )

    {:ok, adaptive_address} =
      EngineSystem.spawn_engine(
        KVStoreEngine,
        %{},
        %{store: %{}},
        :adaptive_kv,
        KVAdaptiveMailboxEngine,
        %{initial_buffer_size: 500}
      )

    # Send identical workloads to all three
    workload = [
      {:put, :key1, :value1},
      {:put, :key2, :value2},
      {:get, :key1},
      # Should be coalesced in priority engine
      {:put, :key1, :updated_value1},
      {:get, :key2},
      {:delete, :key1}
    ]

    Enum.each(workload, fn message ->
      :ok = EngineSystem.send_message(default_address, message)
      :ok = EngineSystem.send_message(priority_address, message)
      :ok = EngineSystem.send_message(adaptive_address, message)
    end)

    # Get performance stats (after a brief delay for processing)
    Process.sleep(100)

    default_stats = EngineSystem.get_system_info()
    priority_stats = KVPriorityMailboxEngine.get_stats(get_mailbox_pid(priority_address))

    adaptive_stats =
      KVAdaptiveMailboxEngine.get_performance_stats(get_mailbox_pid(adaptive_address))

    %{
      default: default_stats,
      priority: priority_stats,
      adaptive: adaptive_stats
    }
  end

  @doc """
  Example 4: Dynamic mailbox policy updates.
  """
  def example_dynamic_updates do
    {:ok, address} =
      EngineSystem.spawn_engine(
        KVStoreEngine,
        %{},
        %{store: %{}},
        :dynamic_kv,
        KVPriorityMailboxEngine,
        %{max_buffer_size: 500, batch_size: 5}
      )

    mailbox_pid = get_mailbox_pid(address)

    # Initial stats
    initial_stats = KVPriorityMailboxEngine.get_stats(mailbox_pid)
    IO.puts("Initial buffer size: #{initial_stats.max_buffer_size}")

    # Update buffer policies at runtime
    :ok =
      KVPriorityMailboxEngine.update_buffer_policy(mailbox_pid, %{
        max_buffer_size: 2000,
        batch_size: 20,
        coalesce_window_ms: 200
      })

    # New stats
    updated_stats = KVPriorityMailboxEngine.get_stats(mailbox_pid)
    IO.puts("Updated buffer size: #{updated_stats.max_buffer_size}")

    {:ok, address}
  end

  @doc """
  Example 5: Monitoring adaptive mailbox behavior.
  """
  def example_adaptive_monitoring do
    {:ok, address} =
      EngineSystem.spawn_engine(
        KVStoreEngine,
        %{},
        %{store: %{}},
        :monitored_kv,
        KVAdaptiveMailboxEngine,
        # Fast adaptation for demo
        %{adaptation_window_ms: 100}
      )

    mailbox_pid = get_mailbox_pid(address)

    # Start monitoring task
    monitor_task =
      Task.async(fn ->
        # Monitor for 5 seconds
        monitor_adaptive_behavior(mailbox_pid, 5)
      end)

    # Generate varying load to trigger adaptations
    generate_varying_load(address)

    # Get monitoring results
    monitoring_results = Task.await(monitor_task, 10_000)

    IO.puts("Adaptation behavior observed:")

    Enum.each(monitoring_results, fn {timestamp, stats} ->
      IO.puts(
        "#{timestamp}: Buffer=#{stats.current_buffer_size}, Batch=#{stats.current_batch_size}, Load=#{stats.load_state}"
      )
    end)

    {:ok, address}
  end

  ## Helper Functions

  defp get_mailbox_pid(engine_address) do
    {:ok, instance_info} = EngineSystem.lookup_instance(engine_address)
    instance_info.mailbox_pid
  end

  defp monitor_adaptive_behavior(mailbox_pid, duration_seconds) do
    end_time = :erlang.system_time(:second) + duration_seconds
    monitor_loop(mailbox_pid, end_time, [])
  end

  defp monitor_loop(mailbox_pid, end_time, acc) do
    current_time = :erlang.system_time(:second)

    if current_time >= end_time do
      Enum.reverse(acc)
    else
      stats = KVAdaptiveMailboxEngine.get_info(mailbox_pid)
      timestamp = :erlang.system_time(:millisecond)

      # Check every 200ms
      Process.sleep(200)
      monitor_loop(mailbox_pid, end_time, [{timestamp, stats} | acc])
    end
  end

  defp generate_varying_load(address) do
    # Phase 1: Light load
    spawn(fn ->
      for i <- 1..20 do
        :ok = EngineSystem.send_message(address, {:put, "light_#{i}", "value"})
        Process.sleep(50)
      end
    end)

    # Phase 2: Heavy load (after 1 second)
    spawn(fn ->
      Process.sleep(1000)

      for i <- 1..100 do
        :ok = EngineSystem.send_message(address, {:put, "heavy_#{i}", "value"})
        Process.sleep(10)
      end
    end)

    # Phase 3: Read-heavy load (after 3 seconds)
    spawn(fn ->
      Process.sleep(3000)

      for i <- 1..50 do
        :ok = EngineSystem.send_message(address, {:get, "heavy_#{rem(i, 10)}"})
        Process.sleep(20)
      end
    end)
  end

  @doc """
  Run all examples in sequence.
  """
  def run_all_examples do
    IO.puts("=== Running Custom Mailbox Engine Examples ===\n")

    IO.puts("1. Priority Mailbox Engine Example:")
    {:ok, _addr1} = example_priority_mailbox()
    IO.puts("✓ Priority mailbox engine created\n")

    IO.puts("2. Adaptive Mailbox Engine Example:")
    {:ok, _addr2} = example_adaptive_mailbox()
    IO.puts("✓ Adaptive mailbox engine created\n")

    IO.puts("3. Performance Comparison:")
    comparison_results = example_performance_comparison()
    IO.inspect(comparison_results, label: "Performance Stats")
    IO.puts("")

    IO.puts("4. Dynamic Policy Updates:")
    {:ok, _addr4} = example_dynamic_updates()
    IO.puts("✓ Policy updates demonstrated\n")

    IO.puts("5. Adaptive Monitoring:")
    {:ok, _addr5} = example_adaptive_monitoring()
    IO.puts("✓ Adaptive behavior monitored\n")

    IO.puts("=== All Examples Completed ===")
  end
end
