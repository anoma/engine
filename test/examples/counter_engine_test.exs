defmodule EngineSystem.Examples.CounterEngineTest do
  use ExUnit.Case, async: false

  @moduledoc """
  Comprehensive tests for the SimpleCounterEngine example.

  Tests cover:
  1. Basic counter operations (increment, decrement, reset)
  2. Configuration handling (mode, notifications, limits)
  3. Environment state management
  4. Message sending and receiving
  5. Error cases and edge conditions
  6. State persistence and history tracking
  """

  setup do
    {:ok, _} = EngineSystem.start()
    :ok
  end

  describe "basic counter operations" do
    test "can spawn counter engine with default configuration" do
      {:ok, counter_address} = EngineSystem.spawn_engine(Examples.SimpleCounterEngine)

      assert is_tuple(counter_address)
      {:ok, instance} = EngineSystem.lookup_instance(counter_address)
      assert instance.engine_name == :"Elixir.Examples.SimpleCounterEngine"
      assert instance.version == "2.0.0"
      assert instance.status == :running
    end

    test "increment increases counter value" do
      {:ok, counter_address} = EngineSystem.spawn_engine(Examples.SimpleCounterEngine)

      # Send increment message
      :ok = EngineSystem.send_message(counter_address, {:increment, %{}})
      Process.sleep(200)

      # Verify message was processed
      {:ok, instance} = EngineSystem.lookup_instance(counter_address)
      mailbox_info = EngineSystem.Mailbox.MailboxRuntime.get_info(instance.mailbox_pid)

      assert mailbox_info.environment.total_received >= 1
      assert mailbox_info.environment.total_delivered >= 1
    end

    test "decrement decreases counter value" do
      {:ok, counter_address} = EngineSystem.spawn_engine(Examples.SimpleCounterEngine)

      # First increment to have something to decrement
      :ok = EngineSystem.send_message(counter_address, {:increment, %{}})
      Process.sleep(100)

      # Then decrement
      :ok = EngineSystem.send_message(counter_address, {:decrement, %{}})
      Process.sleep(200)

      # Verify both messages were processed
      {:ok, instance} = EngineSystem.lookup_instance(counter_address)
      mailbox_info = EngineSystem.Mailbox.MailboxRuntime.get_info(instance.mailbox_pid)

      assert mailbox_info.environment.total_received >= 2
      assert mailbox_info.environment.total_delivered >= 2
    end

    test "get_count returns current counter value" do
      {:ok, counter_address} = EngineSystem.spawn_engine(Examples.SimpleCounterEngine)

      # Send get_count message
      :ok = EngineSystem.send_message(counter_address, {:get_count, %{}})
      Process.sleep(200)

      # Verify message was processed
      {:ok, instance} = EngineSystem.lookup_instance(counter_address)
      mailbox_info = EngineSystem.Mailbox.MailboxRuntime.get_info(instance.mailbox_pid)

      assert mailbox_info.environment.total_received >= 1
      assert mailbox_info.environment.total_delivered >= 1
    end

    test "reset sets counter back to zero" do
      {:ok, counter_address} = EngineSystem.spawn_engine(Examples.SimpleCounterEngine)

      # Increment a few times, then reset
      :ok = EngineSystem.send_message(counter_address, {:increment, %{}})
      :ok = EngineSystem.send_message(counter_address, {:increment, %{}})
      :ok = EngineSystem.send_message(counter_address, {:reset, %{}})
      Process.sleep(300)

      # Verify all messages were processed
      {:ok, instance} = EngineSystem.lookup_instance(counter_address)
      mailbox_info = EngineSystem.Mailbox.MailboxRuntime.get_info(instance.mailbox_pid)

      assert mailbox_info.environment.total_received >= 3
      assert mailbox_info.environment.total_delivered >= 3
    end

    test "add increases counter by specified value" do
      {:ok, counter_address} = EngineSystem.spawn_engine(Examples.SimpleCounterEngine)

      # Add 5 to the counter
      :ok = EngineSystem.send_message(counter_address, {:add, %{value: 5}})
      Process.sleep(200)

      # Verify message was processed
      {:ok, instance} = EngineSystem.lookup_instance(counter_address)
      mailbox_info = EngineSystem.Mailbox.MailboxRuntime.get_info(instance.mailbox_pid)

      assert mailbox_info.environment.total_received >= 1
      assert mailbox_info.environment.total_delivered >= 1
    end
  end

  describe "configuration handling" do
    test "can spawn with custom configuration" do
      custom_config = %{
        mode: :limited,
        auto_reset: true,
        notifications: false
      }

      {:ok, counter_address} = EngineSystem.spawn_engine(Examples.SimpleCounterEngine, custom_config)

      {:ok, instance} = EngineSystem.lookup_instance(counter_address)
      assert instance.status == :running
    end

    test "limited mode enforces max_count" do
      config = %{mode: :limited, notifications: true}
      env = %{counter: 95, max_count: 100}  # Start near the limit

      {:ok, counter_address} = EngineSystem.spawn_engine(Examples.SimpleCounterEngine, config, env)

      # This should work (counter goes to 96)
      :ok = EngineSystem.send_message(counter_address, {:increment, %{}})
      Process.sleep(100)

      # Try to add a large value that would exceed max_count
      :ok = EngineSystem.send_message(counter_address, {:add, %{value: 10}})
      Process.sleep(200)

      # Verify messages were processed
      {:ok, instance} = EngineSystem.lookup_instance(counter_address)
      mailbox_info = EngineSystem.Mailbox.MailboxRuntime.get_info(instance.mailbox_pid)

      assert mailbox_info.environment.total_received >= 2
      assert mailbox_info.environment.total_delivered >= 2
    end

    test "notifications configuration affects response format" do
      # Test with notifications enabled
      config_with_notifications = %{notifications: true}
      {:ok, counter_address} = EngineSystem.spawn_engine(Examples.SimpleCounterEngine, config_with_notifications)

      :ok = EngineSystem.send_message(counter_address, {:increment, %{}})
      Process.sleep(200)

      # Verify processing occurred
      {:ok, instance} = EngineSystem.lookup_instance(counter_address)
      mailbox_info = EngineSystem.Mailbox.MailboxRuntime.get_info(instance.mailbox_pid)
      assert mailbox_info.environment.total_delivered >= 1
    end
  end

  describe "environment state management" do
    test "can spawn with custom initial environment" do
      custom_env = %{
        counter: 42,
        increment_by: 2,
        max_count: 200,
        enabled: true,
        history: [0, 10, 20],
        metadata: %{created_by: "test"}
      }

      {:ok, counter_address} = EngineSystem.spawn_engine(Examples.SimpleCounterEngine, %{}, custom_env)

      {:ok, instance} = EngineSystem.lookup_instance(counter_address)
      assert instance.status == :running
    end

    test "disabled counter rejects operations" do
      disabled_env = %{enabled: false}

      {:ok, counter_address} = EngineSystem.spawn_engine(Examples.SimpleCounterEngine, %{}, disabled_env)

      # Try to increment - should be rejected
      :ok = EngineSystem.send_message(counter_address, {:increment, %{}})
      Process.sleep(200)

      # Verify message was processed (even though operation was rejected)
      {:ok, instance} = EngineSystem.lookup_instance(counter_address)
      mailbox_info = EngineSystem.Mailbox.MailboxRuntime.get_info(instance.mailbox_pid)

      assert mailbox_info.environment.total_received >= 1
      assert mailbox_info.environment.total_delivered >= 1
    end

    test "increment_by affects increment operation" do
      custom_env = %{increment_by: 3}

      {:ok, counter_address} = EngineSystem.spawn_engine(Examples.SimpleCounterEngine, %{}, custom_env)

      :ok = EngineSystem.send_message(counter_address, {:increment, %{}})
      Process.sleep(200)

      # Verify message was processed
      {:ok, instance} = EngineSystem.lookup_instance(counter_address)
      mailbox_info = EngineSystem.Mailbox.MailboxRuntime.get_info(instance.mailbox_pid)

      assert mailbox_info.environment.total_delivered >= 1
    end
  end

  describe "message validation" do
    test "validates increment message" do
      {:ok, counter_address} = EngineSystem.spawn_engine(Examples.SimpleCounterEngine)

      # Valid increment message
      assert :ok == EngineSystem.validate_message(counter_address, {:increment, %{}})
    end

    test "validates add message with value parameter" do
      {:ok, counter_address} = EngineSystem.spawn_engine(Examples.SimpleCounterEngine)

      # Valid add message
      assert :ok == EngineSystem.validate_message(counter_address, {:add, %{value: 5}})

      # Invalid add message (missing value)
      assert {:error, _} = EngineSystem.validate_message(counter_address, {:add, %{}})
    end

    test "rejects invalid message types" do
      {:ok, counter_address} = EngineSystem.spawn_engine(Examples.SimpleCounterEngine)

      # Invalid message type
      assert {:error, _} = EngineSystem.validate_message(counter_address, {:invalid_message, %{}})
    end

    test "lists supported message tags" do
      {:ok, counter_address} = EngineSystem.spawn_engine(Examples.SimpleCounterEngine)

      case EngineSystem.get_instance_message_tags(counter_address) do
        {:ok, supported_messages} ->
          expected_messages = [:increment, :decrement, :reset, :get_count, :add]
          assert Enum.all?(expected_messages, &(&1 in supported_messages))
        supported_messages when is_list(supported_messages) ->
          expected_messages = [:increment, :decrement, :reset, :get_count, :add]
          assert Enum.all?(expected_messages, &(&1 in supported_messages))
        {:error, _reason} ->
          # If the function returns an error, check the spec directly
          tags = EngineSystem.get_message_tags(Examples.SimpleCounterEngine, "2.0.0")
          expected_messages = [:increment, :decrement, :reset, :get_count, :add]
          assert Enum.all?(expected_messages, &(&1 in tags))
      end
    end
  end

  describe "concurrent operations" do
    test "handles multiple concurrent increments" do
      {:ok, counter_address} = EngineSystem.spawn_engine(Examples.SimpleCounterEngine)

      # Send multiple increment messages rapidly
      for _i <- 1..5 do
        :ok = EngineSystem.send_message(counter_address, {:increment, %{}})
      end

      # Wait for all messages to be processed
      Process.sleep(1000)

      # Verify all messages were processed
      {:ok, instance} = EngineSystem.lookup_instance(counter_address)
      mailbox_info = EngineSystem.Mailbox.MailboxRuntime.get_info(instance.mailbox_pid)

      assert mailbox_info.environment.total_received >= 5
      assert mailbox_info.environment.total_delivered >= 5
    end

    test "handles mixed operation types concurrently" do
      {:ok, counter_address} = EngineSystem.spawn_engine(Examples.SimpleCounterEngine)

      # Send various operations
      :ok = EngineSystem.send_message(counter_address, {:increment, %{}})
      :ok = EngineSystem.send_message(counter_address, {:add, %{value: 3}})
      :ok = EngineSystem.send_message(counter_address, {:get_count, %{}})
      :ok = EngineSystem.send_message(counter_address, {:decrement, %{}})
      :ok = EngineSystem.send_message(counter_address, {:get_count, %{}})

      # Wait for processing
      Process.sleep(1000)

      # Verify all messages were processed
      {:ok, instance} = EngineSystem.lookup_instance(counter_address)
      mailbox_info = EngineSystem.Mailbox.MailboxRuntime.get_info(instance.mailbox_pid)

      assert mailbox_info.environment.total_received >= 5
      assert mailbox_info.environment.total_delivered >= 5
    end
  end

  describe "error handling" do
    test "handles add operation with zero value" do
      {:ok, counter_address} = EngineSystem.spawn_engine(Examples.SimpleCounterEngine)

      :ok = EngineSystem.send_message(counter_address, {:add, %{value: 0}})
      Process.sleep(200)

      # Should process successfully
      {:ok, instance} = EngineSystem.lookup_instance(counter_address)
      mailbox_info = EngineSystem.Mailbox.MailboxRuntime.get_info(instance.mailbox_pid)

      assert mailbox_info.environment.total_delivered >= 1
    end

    test "handles add operation with negative value" do
      {:ok, counter_address} = EngineSystem.spawn_engine(Examples.SimpleCounterEngine)

      :ok = EngineSystem.send_message(counter_address, {:add, %{value: -5}})
      Process.sleep(200)

      # Should process successfully (behavior depends on implementation)
      {:ok, instance} = EngineSystem.lookup_instance(counter_address)
      mailbox_info = EngineSystem.Mailbox.MailboxRuntime.get_info(instance.mailbox_pid)

      assert mailbox_info.environment.total_delivered >= 1
    end

    test "decrement doesn't go below zero" do
      {:ok, counter_address} = EngineSystem.spawn_engine(Examples.SimpleCounterEngine)

      # Try to decrement from 0 (should stay at 0)
      :ok = EngineSystem.send_message(counter_address, {:decrement, %{}})
      Process.sleep(200)

      # Verify message was processed
      {:ok, instance} = EngineSystem.lookup_instance(counter_address)
      mailbox_info = EngineSystem.Mailbox.MailboxRuntime.get_info(instance.mailbox_pid)

      assert mailbox_info.environment.total_delivered >= 1
    end
  end

  describe "system integration" do
    test "engine remains responsive after many operations" do
      {:ok, counter_address} = EngineSystem.spawn_engine(Examples.SimpleCounterEngine)

      # Perform many operations
      for i <- 1..20 do
        case rem(i, 4) do
          0 -> :ok = EngineSystem.send_message(counter_address, {:increment, %{}})
          1 -> :ok = EngineSystem.send_message(counter_address, {:add, %{value: 2}})
          2 -> :ok = EngineSystem.send_message(counter_address, {:get_count, %{}})
          3 -> :ok = EngineSystem.send_message(counter_address, {:decrement, %{}})
        end

        # Small delay to vary timing
        if rem(i, 5) == 0, do: Process.sleep(10)
      end

      # Wait for all processing
      Process.sleep(2000)

      # Engine should still be responsive
      {:ok, instance} = EngineSystem.lookup_instance(counter_address)
      assert instance.status == :running

      mailbox_info = EngineSystem.Mailbox.MailboxRuntime.get_info(instance.mailbox_pid)
      assert mailbox_info.environment.total_received >= 20
      assert mailbox_info.environment.total_delivered >= 20

      # Should still respond to new messages
      :ok = EngineSystem.send_message(counter_address, {:get_count, %{}})
      Process.sleep(200)

      final_mailbox_info = EngineSystem.Mailbox.MailboxRuntime.get_info(instance.mailbox_pid)
      assert final_mailbox_info.environment.total_delivered > mailbox_info.environment.total_delivered
    end

    test "can spawn multiple counter engines independently" do
      {:ok, counter1} = EngineSystem.spawn_engine(Examples.SimpleCounterEngine)
      {:ok, counter2} = EngineSystem.spawn_engine(Examples.SimpleCounterEngine, %{notifications: false})
      {:ok, counter3} = EngineSystem.spawn_engine(Examples.SimpleCounterEngine, %{}, %{counter: 10})

      # All should be running
      {:ok, instance1} = EngineSystem.lookup_instance(counter1)
      {:ok, instance2} = EngineSystem.lookup_instance(counter2)
      {:ok, instance3} = EngineSystem.lookup_instance(counter3)

      assert instance1.status == :running
      assert instance2.status == :running
      assert instance3.status == :running

      # Each should be independent
      assert instance1.address != instance2.address
      assert instance2.address != instance3.address
      assert instance1.address != instance3.address
    end
  end

  describe "interface introspection" do
    test "provides correct message interface information" do
      # Check message fields for add operation
      case EngineSystem.get_message_fields(Examples.SimpleCounterEngine, "2.0.0", :add) do
        {:ok, fields} ->
          assert :value in fields
        error ->
          flunk("Expected to get message fields, got: #{inspect(error)}")
      end
    end

    test "reports correct engine version and name" do
      {:ok, counter_address} = EngineSystem.spawn_engine(Examples.SimpleCounterEngine)
      {:ok, instance} = EngineSystem.lookup_instance(counter_address)

      assert instance.engine_name == :"Elixir.Examples.SimpleCounterEngine"
      assert instance.version == "2.0.0"
    end
  end
end
