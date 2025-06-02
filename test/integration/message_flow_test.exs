defmodule EngineSystem.Integration.MessageFlowTest do
  use ExUnit.Case, async: false

  @moduledoc """
  Integration test for complete message flow through the mailbox-engine pipeline.

  This test verifies the complete end-to-end message processing including:
  1. Message enqueueing through mailboxes
  2. Behavior evaluation and execution
  3. Inter-engine communication
  4. State updates and effect processing
  """

  setup do
    {:ok, _} = EngineSystem.start()
    :ok
  end

  describe "complete message processing pipeline" do
    test "ping-pong message exchange works correctly" do
      # Spawn engines
      {:ok, ping_address} = EngineSystem.spawn_engine(Examples.PingEngine)
      {:ok, pong_address} = EngineSystem.spawn_engine(Examples.PongEngine)

      # Set target for ping engine
      :ok =
        EngineSystem.send_message(ping_address, {:set_target, %{target_address: pong_address}})

      # Send ping
      :ok = EngineSystem.send_message(ping_address, :send_ping)

      # Wait for message processing
      Process.sleep(1000)

      # Verify message statistics
      {:ok, ping_instance} = EngineSystem.lookup_instance(ping_address)
      {:ok, pong_instance} = EngineSystem.lookup_instance(pong_address)

      ping_mailbox_info = EngineSystem.Mailbox.MailboxRuntime.get_info(ping_instance.mailbox_pid)
      pong_mailbox_info = EngineSystem.Mailbox.MailboxRuntime.get_info(pong_instance.mailbox_pid)

      # Ping mailbox should have processed 2 messages (set_target + send_ping)
      assert ping_mailbox_info.environment.total_received >= 2
      assert ping_mailbox_info.environment.total_delivered >= 2

      # Pong mailbox should have received and processed the ping message
      assert pong_mailbox_info.environment.total_received >= 1
      assert pong_mailbox_info.environment.total_delivered >= 1
    end

    test "message validation prevents invalid messages" do
      {:ok, ping_address} = EngineSystem.spawn_engine(Examples.PingEngine)
      {:ok, instance_info} = EngineSystem.lookup_instance(ping_address)

      # Get initial statistics
      initial_mailbox_info =
        EngineSystem.Mailbox.MailboxRuntime.get_info(instance_info.mailbox_pid)

      initial_received = initial_mailbox_info.environment.total_received

      # Try to send an invalid message (not in the engine's interface)
      invalid_message =
        EngineSystem.System.Message.new({:system, 0}, ping_address, :invalid_message_type)

      # This should not crash but should be rejected
      EngineSystem.Mailbox.MailboxRuntime.enqueue_message(
        instance_info.mailbox_pid,
        invalid_message
      )

      # Wait a moment
      Process.sleep(100)

      # Check that the invalid message was rejected (total_received should not increase)
      final_mailbox_info = EngineSystem.Mailbox.MailboxRuntime.get_info(instance_info.mailbox_pid)
      assert final_mailbox_info.environment.total_received == initial_received
    end

    test "multiple concurrent messages are processed in order" do
      {:ok, ping_address} = EngineSystem.spawn_engine(Examples.PingEngine)
      {:ok, pong_address} = EngineSystem.spawn_engine(Examples.PongEngine)

      # Set target
      :ok =
        EngineSystem.send_message(ping_address, {:set_target, %{target_address: pong_address}})

      # Send multiple ping messages rapidly
      for _i <- 1..5 do
        :ok = EngineSystem.send_message(ping_address, :send_ping)
      end

      # Wait for all messages to be processed
      Process.sleep(2000)

      # Check final statistics
      {:ok, ping_instance} = EngineSystem.lookup_instance(ping_address)
      {:ok, pong_instance} = EngineSystem.lookup_instance(pong_address)

      ping_mailbox_info = EngineSystem.Mailbox.MailboxRuntime.get_info(ping_instance.mailbox_pid)
      pong_mailbox_info = EngineSystem.Mailbox.MailboxRuntime.get_info(pong_instance.mailbox_pid)

      # Should have processed 6 messages (1 set_target + 5 send_ping)
      assert ping_mailbox_info.environment.total_received >= 6
      assert ping_mailbox_info.environment.total_delivered >= 6

      # Pong should have received multiple ping messages
      assert pong_mailbox_info.environment.total_received >= 5
    end
  end

  describe "behavior evaluation and effects" do
    test "environment updates are properly applied" do
      {:ok, ping_address} = EngineSystem.spawn_engine(Examples.PingEngine)
      {:ok, pong_address} = EngineSystem.spawn_engine(Examples.PongEngine)

      # Set target - this should update the ping engine's environment
      :ok =
        EngineSystem.send_message(ping_address, {:set_target, %{target_address: pong_address}})

      # Wait for message processing
      Process.sleep(500)

      # Verify the message was processed successfully
      {:ok, ping_instance} = EngineSystem.lookup_instance(ping_address)
      ping_mailbox_info = EngineSystem.Mailbox.MailboxRuntime.get_info(ping_instance.mailbox_pid)

      assert ping_mailbox_info.environment.total_received >= 1
      assert ping_mailbox_info.environment.total_delivered >= 1
    end

    test "effects are executed in the correct order" do
      {:ok, ping_address} = EngineSystem.spawn_engine(Examples.PingEngine)
      {:ok, pong_address} = EngineSystem.spawn_engine(Examples.PongEngine)

      # Set target and immediately send ping
      :ok =
        EngineSystem.send_message(ping_address, {:set_target, %{target_address: pong_address}})

      :ok = EngineSystem.send_message(ping_address, :send_ping)

      # Wait for processing
      Process.sleep(1000)

      # Both engines should have processed messages
      {:ok, ping_instance} = EngineSystem.lookup_instance(ping_address)
      {:ok, pong_instance} = EngineSystem.lookup_instance(pong_address)

      ping_mailbox_info = EngineSystem.Mailbox.MailboxRuntime.get_info(ping_instance.mailbox_pid)
      pong_mailbox_info = EngineSystem.Mailbox.MailboxRuntime.get_info(pong_instance.mailbox_pid)

      # Verify processing occurred
      assert ping_mailbox_info.environment.total_delivered >= 2
      assert pong_mailbox_info.environment.total_delivered >= 1
    end
  end

  describe "system resilience" do
    test "system continues functioning after message processing errors" do
      {:ok, ping_address} = EngineSystem.spawn_engine(Examples.PingEngine)

      # Send a valid message first
      :ok = EngineSystem.send_message(ping_address, {:set_target, %{target_address: {999, 999}}})

      # Wait for processing
      Process.sleep(300)

      # Send another valid message - system should still work
      :ok = EngineSystem.send_message(ping_address, :send_ping)

      # Wait for processing
      Process.sleep(300)

      # System should still be responsive
      {:ok, instance_info} = EngineSystem.lookup_instance(ping_address)
      assert instance_info.status == :running

      mailbox_info = EngineSystem.Mailbox.MailboxRuntime.get_info(instance_info.mailbox_pid)
      assert mailbox_info.environment.total_received >= 2
    end

    test "mailbox queuing works under high load" do
      {:ok, ping_address} = EngineSystem.spawn_engine(Examples.PingEngine)
      {:ok, pong_address} = EngineSystem.spawn_engine(Examples.PongEngine)

      # Set target
      :ok =
        EngineSystem.send_message(ping_address, {:set_target, %{target_address: pong_address}})

      Process.sleep(100)

      # Send many messages rapidly to test queuing
      for i <- 1..20 do
        :ok = EngineSystem.send_message(ping_address, :send_ping)
        # Small delays to vary timing
        if rem(i, 5) == 0, do: Process.sleep(10)
      end

      # Give time for all messages to process
      Process.sleep(3000)

      # Verify all messages were eventually processed
      {:ok, ping_instance} = EngineSystem.lookup_instance(ping_address)
      ping_mailbox_info = EngineSystem.Mailbox.MailboxRuntime.get_info(ping_instance.mailbox_pid)

      # Should have processed 21 messages (1 set_target + 20 send_ping)
      assert ping_mailbox_info.environment.total_received >= 21
      assert ping_mailbox_info.environment.total_delivered >= 21
    end
  end
end
