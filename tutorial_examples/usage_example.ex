defmodule TutorialExamples.UsageExample do
  @moduledoc """
  Example showing how to use the EngineSystem with the complete KV store.

  This demonstrates:
  - Starting the system
  - Creating engine instances
  - Sending messages
  - Handling responses
  """

  alias EngineSystem.System.Services

  def run_example do
    IO.puts("🚀 Starting EngineSystem Tutorial Example")

    # 1. Start the system services (if not already started)
    {:ok, _pid} = Services.start_link()
    IO.puts("✅ System services started")

    # 2. Wait for engine type registration
    wait_for_registration()

    # 3. Verify the engine type is registered
    case Services.get_engine_type_info(TutorialExamples.KVStore, "2.0") do
      {:ok, type_info} ->
        IO.puts("✅ Engine type registered: #{type_info.name} v#{type_info.version}")
        show_engine_capabilities(type_info)

      {:error, reason} ->
        IO.puts("❌ Engine type not found: #{inspect(reason)}")
        return
    end

    # 4. Create engine instances with different configurations
    create_and_test_engines()
  end

  defp wait_for_registration do
    # Give the system time to register the engine type
    Process.sleep(100)
  end

  defp show_engine_capabilities(type_info) do
    IO.puts("\n📋 Engine Capabilities:")
    IO.puts("   Type: #{type_info.name}")
    IO.puts("   Version: #{type_info.version}")

    IO.puts("   Messages:")
    Enum.each(type_info.message_interface_spec.messages, fn msg ->
      IO.puts("     - #{msg.tag}")
    end)

    IO.puts("   Guarded Actions:")
    Enum.each(type_info.behaviour_spec.guarded_actions, fn action ->
      IO.puts("     - #{action.message_tag}")
    end)
  end

  defp create_and_test_engines do
    IO.puts("\n🏗️  Creating Engine Instances")

    # Create a standard read-write engine
    rw_config = %{
      parent: nil,
      mode: :process,
      read_only: false,
      max_size: 100,
      ttl_seconds: 60
    }

    case Services.create_engine_instance(TutorialExamples.KVStore, rw_config) do
      {:ok, rw_engine_address} ->
        IO.puts("✅ Read-write engine created: #{inspect(rw_engine_address)}")
        test_read_write_operations(rw_engine_address)

      {:error, reason} ->
        IO.puts("❌ Failed to create read-write engine: #{inspect(reason)}")
    end

    # Create a read-only engine
    ro_config = %{
      parent: nil,
      mode: :process,
      read_only: true,
      max_size: 100,
      ttl_seconds: 60
    }

    case Services.create_engine_instance(TutorialExamples.KVStore, ro_config) do
      {:ok, ro_engine_address} ->
        IO.puts("✅ Read-only engine created: #{inspect(ro_engine_address)}")
        test_read_only_operations(ro_engine_address)

      {:error, reason} ->
        IO.puts("❌ Failed to create read-only engine: #{inspect(reason)}")
    end
  end

  defp test_read_write_operations(engine_address) do
    IO.puts("\n🧪 Testing Read-Write Operations")

    # Test PUT operation
    result = Services.send_message(engine_address, {:put, "key1", "value1"})
    IO.puts("   PUT key1=value1: #{inspect(result)}")

    # Test GET operation
    result = Services.send_message(engine_address, {:get, "key1"})
    IO.puts("   GET key1: #{inspect(result)}")

    # Test EXISTS operation
    result = Services.send_message(engine_address, {:exists, "key1"})
    IO.puts("   EXISTS key1: #{inspect(result)}")

    # Test SIZE operation
    result = Services.send_message(engine_address, {:size})
    IO.puts("   SIZE: #{inspect(result)}")

    # Test KEYS operation
    result = Services.send_message(engine_address, {:keys})
    IO.puts("   KEYS: #{inspect(result)}")

    # Test DELETE operation
    result = Services.send_message(engine_address, {:delete, "key1"})
    IO.puts("   DELETE key1: #{inspect(result)}")

    # Test GET after delete
    result = Services.send_message(engine_address, {:get, "key1"})
    IO.puts("   GET key1 (after delete): #{inspect(result)}")
  end

  defp test_read_only_operations(engine_address) do
    IO.puts("\n🔒 Testing Read-Only Operations")

    # Test PUT operation (should fail)
    result = Services.send_message(engine_address, {:put, "key2", "value2"})
    IO.puts("   PUT key2=value2 (read-only): #{inspect(result)}")

    # Test GET operation (should work)
    result = Services.send_message(engine_address, {:get, "key2"})
    IO.puts("   GET key2: #{inspect(result)}")

    # Test DELETE operation (should fail)
    result = Services.send_message(engine_address, {:delete, "key2"})
    IO.puts("   DELETE key2 (read-only): #{inspect(result)}")

    # Test CLEAR operation (should fail)
    result = Services.send_message(engine_address, {:clear})
    IO.puts("   CLEAR (read-only): #{inspect(result)}")
  end

  def demonstrate_advanced_features do
    IO.puts("\n🎯 Advanced Features Demo")

    # Show engine type discovery
    case Services.list_engine_types() do
      {:ok, types} ->
        IO.puts("📦 Registered Engine Types:")
        Enum.each(types, fn type_info ->
          IO.puts("   - #{type_info.name} v#{type_info.version}")
        end)

      {:error, reason} ->
        IO.puts("❌ Failed to list engine types: #{inspect(reason)}")
    end

    # Show engine instance discovery
    case Services.list_engine_instances() do
      {:ok, instances} ->
        IO.puts("\n🏃 Running Engine Instances:")
        Enum.each(instances, fn instance ->
          IO.puts("   - #{inspect(instance.address)} (#{instance.type_name} v#{instance.type_version})")
        end)

      {:error, reason} ->
        IO.puts("❌ Failed to list engine instances: #{inspect(reason)}")
    end

    # Show system information
    case Services.get_system_info() do
      {:ok, system_info} ->
        IO.puts("\n📊 System Information:")
        IO.puts("   Version: #{system_info.version}")
        IO.puts("   Started at: #{system_info.started_at}")
        IO.puts("   Engine types: #{system_info.engine_type_count}")
        IO.puts("   Engine instances: #{system_info.engine_instance_count}")

      {:error, reason} ->
        IO.puts("❌ Failed to get system info: #{inspect(reason)}")
    end
  end
end

# Example of running the tutorial
# TutorialExamples.UsageExample.run_example()
# TutorialExamples.UsageExample.demonstrate_advanced_features()
