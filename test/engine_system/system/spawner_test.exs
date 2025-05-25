defmodule EngineSystem.System.SpawnerTest do
  use ExUnit.Case, async: true

  alias EngineSystem.System.{Spawner, Registry}
  # alias EngineSystem.Engine.{Spec, State}
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

  describe "register_instance/5" do
    test "successfully registers a valid instance" do
      name = :test_engine

      # Call the private function through spawn_engine (which uses it internally)
      assert {:ok, address} = Spawner.spawn_engine(KVStoreEngine, nil, nil, name)

      # Verify the instance was registered
      assert {:ok, instance_info} = Registry.lookup_instance(address)
      assert instance_info.address == address
      assert instance_info.status == :running

      # Verify name mapping works
      assert {:ok, ^address} = Registry.lookup_address_by_name(name)
    end

    test "handles name conflicts gracefully" do
      name = :duplicate_name

      # Register first instance
      assert {:ok, address1} = Spawner.spawn_engine(KVStoreEngine, nil, nil, name)

      # Try to register second instance with same name - should fail
      assert {:error, _reason} = Spawner.spawn_engine(KVStoreEngine, nil, nil, name)

      # First instance should still be accessible
      assert {:ok, ^address1} = Registry.lookup_address_by_name(name)
    end

    test "allows multiple instances without names" do
      # Should be able to create multiple unnamed instances
      assert {:ok, address1} = Spawner.spawn_engine(KVStoreEngine)
      assert {:ok, address2} = Spawner.spawn_engine(KVStoreEngine)

      assert address1 != address2

      # Both should be registered
      assert {:ok, _info1} = Registry.lookup_instance(address1)
      assert {:ok, _info2} = Registry.lookup_instance(address2)
    end
  end

  describe "validation" do
    test "validates engine spec exists" do
      # Try to spawn an engine with non-existent spec
      assert {:error, {:invalid_engine_module, NonExistentEngine}} =
               Spawner.spawn_engine(NonExistentEngine)
    end
  end
end
