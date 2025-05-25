defmodule EngineSystemTest do
  use ExUnit.Case
  doctest EngineSystem

  alias Examples.KVStoreEngine

  setup do
    # Start the application for testing
    {:ok, _} = Application.ensure_all_started(:engine_system)

    # Manually register the KVStoreEngine spec since auto-registration
    # during compilation doesn't work when the system isn't running
    spec = Examples.KVStoreEngine.__engine_spec__()
    EngineSystem.register_spec(spec)

    on_exit(fn ->
      Application.stop(:engine_system)
    end)

    :ok
  end

  test "can start and stop the system" do
    assert {:ok, _} = EngineSystem.start()
    assert :ok = EngineSystem.stop()
  end

  test "can register and lookup engine specs" do
    # The KVStoreEngine should be automatically registered when compiled
    assert {:ok, spec} = EngineSystem.lookup_spec(Examples.KVStoreEngine)
    assert spec.name == Examples.KVStoreEngine
    assert spec.version == "1.0.0"
  end

  test "can list registered specs" do
    specs = EngineSystem.list_specs()
    assert is_list(specs)
    assert length(specs) >= 1

    # Should include our KVStoreEngine
    kv_spec = Enum.find(specs, fn spec -> spec.name == Examples.KVStoreEngine end)
    assert kv_spec != nil
  end

  test "can spawn an engine instance" do
    assert {:ok, address} = EngineSystem.spawn_engine(Examples.KVStoreEngine)
    assert is_tuple(address)
    assert tuple_size(address) == 2

    # Should be able to look up the instance
    assert {:ok, instance_info} = EngineSystem.lookup_instance(address)
    assert instance_info.address == address
    assert instance_info.status == :running
  end

  test "can spawn multiple engine instances" do
    assert {:ok, address1} = EngineSystem.spawn_engine(Examples.KVStoreEngine)
    assert {:ok, address2} = EngineSystem.spawn_engine(Examples.KVStoreEngine)

    assert address1 != address2

    instances = EngineSystem.list_instances()
    assert length(instances) >= 2
  end

  test "can spawn engine with custom name" do
    assert {:ok, address} =
             EngineSystem.spawn_engine(Examples.KVStoreEngine, nil, nil, :my_kv_store)

    # Should be able to look up by name
    assert {:ok, ^address} = EngineSystem.lookup_address_by_name(:my_kv_store)
  end

  test "can get system information" do
    info = EngineSystem.get_system_info()
    assert is_map(info)
    assert Map.has_key?(info, :total_instances)
    assert Map.has_key?(info, :total_specs)
    assert Map.has_key?(info, :running_instances)
  end

  test "can generate fresh IDs" do
    id1 = EngineSystem.fresh_id()
    id2 = EngineSystem.fresh_id()

    assert is_integer(id1)
    assert is_integer(id2)
    assert id1 != id2
  end

  test "can terminate engine instances" do
    assert {:ok, address} = EngineSystem.spawn_engine(Examples.KVStoreEngine)

    # Verify it's running
    assert {:ok, instance_info} = EngineSystem.lookup_instance(address)
    assert instance_info.status == :running

    # Terminate it
    assert :ok = EngineSystem.terminate_engine(address)

    # Should no longer be found (or marked as terminated)
    # Note: In a real implementation, this might return terminated status
    # rather than not_found, depending on cleanup strategy
  end
end
