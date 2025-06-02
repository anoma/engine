defmodule EngineSystem.Integration.MailboxParentRelationshipTest do
  use ExUnit.Case, async: false

  @moduledoc """
  Integration test to verify that the mailbox-engine parent relationship is working correctly.

  This test ensures that:
  1. Mailbox engines are properly configured with their processing engine as parent
  2. The parent-child relationship is established correctly during spawning
  3. Message flow works through the mailbox-engine pipeline
  """

  setup do
    # Start the system for each test
    {:ok, _} = EngineSystem.start()
    :ok
  end

  describe "mailbox-engine parent relationship" do
    test "spawning processing engine establishes correct parent relationship" do
      # Spawn a processing engine
      {:ok, ping_address} = EngineSystem.spawn_engine(Examples.PingEngine)

      # Look up the instance to get mailbox info
      {:ok, instance_info} = EngineSystem.lookup_instance(ping_address)

      assert instance_info.engine_pid != nil
      assert instance_info.mailbox_pid != nil

      # Check mailbox configuration
      mailbox_info = EngineSystem.Mailbox.MailboxRuntime.get_info(instance_info.mailbox_pid)

      # Verify parent is set correctly
      parent = Map.get(mailbox_info.configuration, :parent)

      assert parent == instance_info.engine_pid,
             "Expected mailbox parent to be processing engine PID #{inspect(instance_info.engine_pid)}, got #{inspect(parent)}"
    end

    test "mailbox environment contains processing engine information" do
      {:ok, ping_address} = EngineSystem.spawn_engine(Examples.PingEngine)
      {:ok, instance_info} = EngineSystem.lookup_instance(ping_address)

      mailbox_info = EngineSystem.Mailbox.MailboxRuntime.get_info(instance_info.mailbox_pid)

      # Verify processing engine info is properly set in mailbox environment
      assert mailbox_info.environment.pe_address == ping_address
      assert mailbox_info.environment.pe_pid == instance_info.engine_pid
      assert mailbox_info.environment.pe_spec != nil
    end
  end

  describe "message flow through mailbox-engine pipeline" do
    test "messages flow correctly from mailbox to processing engine" do
      # Spawn engines
      {:ok, ping_address} = EngineSystem.spawn_engine(Examples.PingEngine)
      {:ok, pong_address} = EngineSystem.spawn_engine(Examples.PongEngine)

      # Set target for ping engine
      :ok =
        EngineSystem.send_message(ping_address, {:set_target, %{target_address: pong_address}})

      # Send ping
      :ok = EngineSystem.send_message(ping_address, :send_ping)

      # Wait for message processing
      Process.sleep(500)

      # Check that messages were processed by checking mailbox statistics
      {:ok, ping_instance} = EngineSystem.lookup_instance(ping_address)
      ping_mailbox_info = EngineSystem.Mailbox.MailboxRuntime.get_info(ping_instance.mailbox_pid)

      # Verify messages were received and delivered
      # set_target + send_ping
      assert ping_mailbox_info.environment.total_received >= 2
      assert ping_mailbox_info.environment.total_delivered >= 2
    end

    test "multiple instances maintain separate parent relationships" do
      # Spawn multiple engines
      {:ok, ping1_address} = EngineSystem.spawn_engine(Examples.PingEngine)
      {:ok, ping2_address} = EngineSystem.spawn_engine(Examples.PingEngine)
      {:ok, pong_address} = EngineSystem.spawn_engine(Examples.PongEngine)

      # Get instance information
      {:ok, ping1_info} = EngineSystem.lookup_instance(ping1_address)
      {:ok, ping2_info} = EngineSystem.lookup_instance(ping2_address)
      {:ok, pong_info} = EngineSystem.lookup_instance(pong_address)

      # Get mailbox information
      ping1_mailbox_info = EngineSystem.Mailbox.MailboxRuntime.get_info(ping1_info.mailbox_pid)
      ping2_mailbox_info = EngineSystem.Mailbox.MailboxRuntime.get_info(ping2_info.mailbox_pid)
      pong_mailbox_info = EngineSystem.Mailbox.MailboxRuntime.get_info(pong_info.mailbox_pid)

      # Verify each mailbox has its own processing engine as parent
      assert ping1_mailbox_info.configuration.parent == ping1_info.engine_pid
      assert ping2_mailbox_info.configuration.parent == ping2_info.engine_pid
      assert pong_mailbox_info.configuration.parent == pong_info.engine_pid

      # Verify parents are different
      assert ping1_info.engine_pid != ping2_info.engine_pid
      assert ping1_info.engine_pid != pong_info.engine_pid
      assert ping2_info.engine_pid != pong_info.engine_pid
    end
  end

  describe "system state verification" do
    test "instances are properly registered and trackable" do
      # Spawn engines
      {:ok, ping_address} = EngineSystem.spawn_engine(Examples.PingEngine)
      {:ok, pong_address} = EngineSystem.spawn_engine(Examples.PongEngine)

      # Check system state
      instances = EngineSystem.list_instances()

      assert length(instances) >= 2

      # Find our instances
      ping_instance = Enum.find(instances, fn instance -> instance.address == ping_address end)
      pong_instance = Enum.find(instances, fn instance -> instance.address == pong_address end)

      assert ping_instance != nil
      assert pong_instance != nil
      assert ping_instance.status == :running
      assert pong_instance.status == :running
    end
  end
end
