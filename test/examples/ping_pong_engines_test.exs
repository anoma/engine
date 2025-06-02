defmodule EngineSystem.Examples.PingPongEnginesTest do
  use ExUnit.Case, async: false

  @moduledoc """
  Tests for the example ping and pong engines.

  These tests verify that the example engines work correctly both individually
  and when interacting with each other.
  """

  setup do
    {:ok, _} = EngineSystem.start()
    :ok
  end

  describe "PingEngine" do
    test "has correct specification" do
      spec = Examples.PingEngine.__engine_spec__()

      assert spec.name == Examples.PingEngine
      assert spec.version == "1.0.0"
      assert spec.mode == :process

      # Check interface
      expected_messages = [:ping, :pong, :set_target, :send_ping]
      interface_messages = Keyword.keys(spec.interface)
      assert Enum.all?(expected_messages, fn msg -> msg in interface_messages end)

      # Check behavior rules
      rule_tags = Keyword.keys(spec.behaviour_rules)
      assert Enum.all?(expected_messages, fn msg -> msg in rule_tags end)

      # Check environment spec
      assert spec.env_spec.default.ping_count == 0
      assert spec.env_spec.default.target == nil
    end

    test "spawns successfully" do
      {:ok, address} = EngineSystem.spawn_engine(Examples.PingEngine)
      {:ok, instance_info} = EngineSystem.lookup_instance(address)

      assert instance_info.status == :running
      assert instance_info.engine_pid != nil
      assert instance_info.mailbox_pid != nil
    end

    test "can set target" do
      {:ok, ping_address} = EngineSystem.spawn_engine(Examples.PingEngine)
      target_address = {999, 999}

      :ok =
        EngineSystem.send_message(ping_address, {:set_target, %{target_address: target_address}})

      # Wait for processing
      Process.sleep(200)

      # Verify message was processed
      {:ok, instance_info} = EngineSystem.lookup_instance(ping_address)
      mailbox_info = EngineSystem.Mailbox.MailboxRuntime.get_info(instance_info.mailbox_pid)

      assert mailbox_info.environment.total_received >= 1
      assert mailbox_info.environment.total_delivered >= 1
    end

    test "can send ping when target is set" do
      {:ok, ping_address} = EngineSystem.spawn_engine(Examples.PingEngine)
      target_address = {999, 999}

      # Set target first
      :ok =
        EngineSystem.send_message(ping_address, {:set_target, %{target_address: target_address}})

      Process.sleep(100)

      # Send ping
      :ok = EngineSystem.send_message(ping_address, :send_ping)
      Process.sleep(200)

      # Verify both messages were processed
      {:ok, instance_info} = EngineSystem.lookup_instance(ping_address)
      mailbox_info = EngineSystem.Mailbox.MailboxRuntime.get_info(instance_info.mailbox_pid)

      assert mailbox_info.environment.total_received >= 2
      assert mailbox_info.environment.total_delivered >= 2
    end
  end

  describe "PongEngine" do
    test "has correct specification" do
      spec = Examples.PongEngine.__engine_spec__()

      assert spec.name == Examples.PongEngine
      assert spec.version == "1.0.0"
      assert spec.mode == :process

      # Check interface
      expected_messages = [:ping, :pong]
      interface_messages = Keyword.keys(spec.interface)
      assert Enum.all?(expected_messages, fn msg -> msg in interface_messages end)

      # Check environment spec
      assert spec.env_spec.default.pong_count == 0
    end

    test "spawns successfully" do
      {:ok, address} = EngineSystem.spawn_engine(Examples.PongEngine)
      {:ok, instance_info} = EngineSystem.lookup_instance(address)

      assert instance_info.status == :running
      assert instance_info.engine_pid != nil
      assert instance_info.mailbox_pid != nil
    end

    test "responds to ping messages" do
      {:ok, pong_address} = EngineSystem.spawn_engine(Examples.PongEngine)

      # Send a ping message
      :ok = EngineSystem.send_message(pong_address, :ping)

      # Wait for processing
      Process.sleep(200)

      # Verify message was processed
      {:ok, instance_info} = EngineSystem.lookup_instance(pong_address)
      mailbox_info = EngineSystem.Mailbox.MailboxRuntime.get_info(instance_info.mailbox_pid)

      assert mailbox_info.environment.total_received >= 1
      assert mailbox_info.environment.total_delivered >= 1
    end
  end

  describe "Ping-Pong interaction" do
    test "complete ping-pong exchange works" do
      # Spawn both engines
      {:ok, ping_address} = EngineSystem.spawn_engine(Examples.PingEngine)
      {:ok, pong_address} = EngineSystem.spawn_engine(Examples.PongEngine)

      # Set pong as target for ping
      :ok =
        EngineSystem.send_message(ping_address, {:set_target, %{target_address: pong_address}})

      Process.sleep(100)

      # Send ping
      :ok = EngineSystem.send_message(ping_address, :send_ping)

      # Wait for the complete exchange
      Process.sleep(1000)

      # Check both engines processed messages
      {:ok, ping_instance} = EngineSystem.lookup_instance(ping_address)
      {:ok, pong_instance} = EngineSystem.lookup_instance(pong_address)

      ping_mailbox_info = EngineSystem.Mailbox.MailboxRuntime.get_info(ping_instance.mailbox_pid)
      pong_mailbox_info = EngineSystem.Mailbox.MailboxRuntime.get_info(pong_instance.mailbox_pid)

      # Ping should have processed set_target and send_ping
      assert ping_mailbox_info.environment.total_received >= 2
      assert ping_mailbox_info.environment.total_delivered >= 2

      # Pong should have received and processed the ping
      assert pong_mailbox_info.environment.total_received >= 1
      assert pong_mailbox_info.environment.total_delivered >= 1
    end

    test "multiple ping-pong exchanges work" do
      # Spawn both engines
      {:ok, ping_address} = EngineSystem.spawn_engine(Examples.PingEngine)
      {:ok, pong_address} = EngineSystem.spawn_engine(Examples.PongEngine)

      # Set target
      :ok =
        EngineSystem.send_message(ping_address, {:set_target, %{target_address: pong_address}})

      Process.sleep(100)

      # Send multiple pings
      for _i <- 1..3 do
        :ok = EngineSystem.send_message(ping_address, :send_ping)
        # Small delay between pings
        Process.sleep(100)
      end

      # Wait for all processing to complete
      Process.sleep(1000)

      # Check message counts
      {:ok, ping_instance} = EngineSystem.lookup_instance(ping_address)
      {:ok, pong_instance} = EngineSystem.lookup_instance(pong_address)

      ping_mailbox_info = EngineSystem.Mailbox.MailboxRuntime.get_info(ping_instance.mailbox_pid)
      pong_mailbox_info = EngineSystem.Mailbox.MailboxRuntime.get_info(pong_instance.mailbox_pid)

      # Ping should have processed 4 messages (1 set_target + 3 send_ping)
      assert ping_mailbox_info.environment.total_received >= 4
      assert ping_mailbox_info.environment.total_delivered >= 4

      # Pong should have received multiple ping messages
      assert pong_mailbox_info.environment.total_received >= 3
      assert pong_mailbox_info.environment.total_delivered >= 3
    end

    test "engines handle invalid messages gracefully" do
      {:ok, ping_address} = EngineSystem.spawn_engine(Examples.PingEngine)

      # Get initial state
      {:ok, initial_instance} = EngineSystem.lookup_instance(ping_address)

      initial_mailbox_info =
        EngineSystem.Mailbox.MailboxRuntime.get_info(initial_instance.mailbox_pid)

      initial_received = initial_mailbox_info.environment.total_received

      # Try to send an invalid message directly to mailbox
      invalid_message = EngineSystem.System.Message.new({:test, 1}, ping_address, :invalid_msg)

      EngineSystem.Mailbox.MailboxRuntime.enqueue_message(
        initial_instance.mailbox_pid,
        invalid_message
      )

      Process.sleep(200)

      # Check that invalid message was rejected
      {:ok, final_instance} = EngineSystem.lookup_instance(ping_address)

      final_mailbox_info =
        EngineSystem.Mailbox.MailboxRuntime.get_info(final_instance.mailbox_pid)

      # Should not have increased received count
      assert final_mailbox_info.environment.total_received == initial_received

      # Engine should still be functional
      assert final_instance.status == :running
    end
  end

  describe "engine handler functions" do
    test "PingEngine has required handler functions" do
      functions = Examples.PingEngine.__info__(:functions)

      required_handlers = [
        :__handle_ping__,
        :__handle_pong__,
        :__handle_set_target__,
        :__handle_send_ping__
      ]

      for handler <- required_handlers do
        assert {handler, 4} in functions, "Missing handler: #{handler}/4"
      end
    end

    test "PongEngine has required handler functions" do
      functions = Examples.PongEngine.__info__(:functions)

      required_handlers = [
        :__handle_ping__,
        :__handle_pong__
      ]

      for handler <- required_handlers do
        assert {handler, 4} in functions, "Missing handler: #{handler}/4"
      end
    end
  end
end
