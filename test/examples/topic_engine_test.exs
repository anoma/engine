defmodule EngineSystem.Examples.TopicEngineTest do
  use ExUnit.Case, async: false

  @moduledoc """
  Tests for the example topic engine.

  TODO
  """

  setup do
    {:ok, _} = EngineSystem.start()
    :ok
  end

  describe "Pub/Sub Topic Engine" do
    test "spawns successfully" do
      {:ok, address} = EngineSystem.spawn_engine(Examples.TopicEngine)
      {:ok, instance_info} = EngineSystem.lookup_instance(address)

      assert instance_info.status == :running
      assert instance_info.engine_pid != nil
      assert instance_info.mailbox_pid != nil
    end

    test "can send & receive message" do
      {:ok, address} = EngineSystem.spawn_engine(Examples.PingEngine)

      :ok =
        EngineSystem.send_message(address, {:new})

      :ok =
        EngineSystem.send_message(address, {:publish, {:test_msg}})

      # Wait for processing
      Process.sleep(200)

      # Verify message was processed
      {:ok, instance_info} = EngineSystem.lookup_instance(address)
      mailbox_info = EngineSystem.Mailbox.MailboxRuntime.get_info(instance_info.mailbox_pid)

      assert mailbox_info.environment.total_received >= 1
      assert mailbox_info.environment.total_delivered >= 1
    end
  end
end
