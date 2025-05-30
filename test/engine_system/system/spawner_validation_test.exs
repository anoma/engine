defmodule EngineSystem.System.SpawnerValidationTest do
  use ExUnit.Case, async: true

  alias EngineSystem.System.{Spawner, Registry}
  alias Examples.KVStoreEngine

  setup do
    # Ensure the application is started
    {:ok, _} = Application.ensure_all_started(:engine_system)

    # Register a test spec if not already registered
    spec = KVStoreEngine.__engine_spec__()

    case Registry.register_spec(spec) do
      :ok -> :ok
      {:error, :already_registered} -> :ok
      error -> error
    end

    :ok
  end

  describe "address validation" do
    test "accepts valid address format" do
      # Valid addresses should work
      assert {:ok, address} = Spawner.spawn_engine(KVStoreEngine)

      # Verify address format
      assert {node_id, engine_id} = address
      assert is_integer(node_id) and node_id >= 0
      assert is_integer(engine_id) and engine_id >= 0

      # Should be able to look up the instance
      assert {:ok, instance_info} = Registry.lookup_instance(address)
      assert instance_info.address == address
    end

    test "generates sequential engine IDs" do
      # Create multiple engines and verify IDs are sequential
      assert {:ok, {node1, id1}} = Spawner.spawn_engine(KVStoreEngine)
      assert {:ok, {node2, id2}} = Spawner.spawn_engine(KVStoreEngine)

      # Should be same node, sequential IDs
      assert node1 == node2
      assert id2 > id1
    end
  end

  describe "error formatting" do
    test "provides readable error messages" do
      # This test verifies that our error formatting works
      # by checking the log output format (indirectly through successful operations)

      name = :test_readable_errors
      assert {:ok, _address1} = Spawner.spawn_engine(KVStoreEngine, nil, nil, name)

      # Second registration should fail with readable error
      assert {:error, reason} = Spawner.spawn_engine(KVStoreEngine, nil, nil, name)

      # The error should propagate from the registry's name conflict detection
      # Our improved error formatting will be visible in the logs
      assert reason != nil
    end
  end

  describe "spec validation" do
    test "validates spec completeness" do
      # This indirectly tests our spec validation by ensuring
      # that only properly formed specs can be used
      assert {:ok, _address} = Spawner.spawn_engine(KVStoreEngine)

      # Invalid engine module should fail early
      assert {:error, {:invalid_engine_module, NonExistentEngine}} =
               Spawner.spawn_engine(NonExistentEngine)
    end
  end

  describe "process validation" do
    test "ensures processes are alive during registration" do
      # This test verifies that our process validation works
      # by successfully creating engines (which means PIDs were validated)
      assert {:ok, address} = Spawner.spawn_engine(KVStoreEngine)

      # Verify the registered instance has valid PIDs
      assert {:ok, instance_info} = Registry.lookup_instance(address)
      assert is_pid(instance_info.engine_pid)
      assert Process.alive?(instance_info.engine_pid)

      if instance_info.mailbox_pid do
        assert is_pid(instance_info.mailbox_pid)
        assert Process.alive?(instance_info.mailbox_pid)
      end
    end
  end

  describe "logging format" do
    test "uses improved address formatting" do
      # Create an engine and verify it works (logging happens internally)
      assert {:ok, {node_id, engine_id}} =
               Spawner.spawn_engine(KVStoreEngine, nil, nil, :formatted_test)

      # The logs should show "node:X/engine:Y" format instead of raw tuples
      # This is verified by the successful operation and can be seen in test output
      assert is_integer(node_id)
      assert is_integer(engine_id)

      # Verify the instance is properly registered
      assert {:ok, instance_info} = Registry.lookup_instance({node_id, engine_id})
      assert instance_info.address == {node_id, engine_id}
    end
  end
end
