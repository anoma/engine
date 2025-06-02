defmodule Examples.TestDemo do
  @moduledoc """
  Simple test to verify the engine interaction demo works.
  """

  def run_test do
    IO.puts("\n🧪 Running EngineSystem Test Demo...")

    # Start the demo
    case Examples.InteractiveDemo.start_demo() do
      {:error, reason} ->
        IO.puts("❌ Failed to start demo: #{inspect(reason)}")

      _ ->
        IO.puts("✅ Demo started successfully!")

        # Wait a bit for engines to be ready
        Process.sleep(1000)

        # Check status
        Examples.InteractiveDemo.status()

        # Test Engine-to-Engine communication
        IO.puts("\n🧪 Testing Engine-to-Engine Communication...")
        Examples.InteractiveDemo.test_engine_to_engine()

        # Wait a bit
        Process.sleep(2000)

        # Test GenServer-to-Engine communication
        IO.puts("\n🧪 Testing GenServer-to-Engine Communication...")
        Examples.InteractiveDemo.test_genserver_to_engine()

        # Wait a bit
        Process.sleep(2000)

        # Test Engine-to-GenServer communication
        IO.puts("\n🧪 Testing Engine-to-GenServer Communication...")
        Examples.InteractiveDemo.test_engine_to_genserver()

        # Wait a bit
        Process.sleep(2000)

        # Final status
        IO.puts("\n🏁 Final Status:")
        Examples.InteractiveDemo.status()

        IO.puts("\n✅ Test Demo Complete!")
    end
  end

  def quick_ping_test do
    IO.puts("\n🏓 Quick Ping Test...")

    # Start system
    EngineSystem.API.start_system()

    # Spawn two engines
    {:ok, ping_addr} = EngineSystem.API.spawn_engine(Examples.PingEngine, %{}, %{})
    {:ok, pong_addr} = EngineSystem.API.spawn_engine(Examples.PongEngine, %{}, %{})

    IO.puts("🎯 PingEngine: #{inspect(ping_addr)}")
    IO.puts("🏓 PongEngine: #{inspect(pong_addr)}")

    # Create target relationship
    EngineSystem.API.send_message(ping_addr, {:set_target, pong_addr}, {0, 0})

    # Send a ping to start the demo
    EngineSystem.API.send_message(ping_addr, :send_ping, {0, 0})

    IO.puts("👀 Watch the output for ping-pong messages!")

    Process.sleep(2000)
    IO.puts("✅ Quick test complete!")
  end

  def echo_test do
    IO.puts("\n📢 Echo Test...")

    # Start system
    EngineSystem.API.start_system()

    # Spawn echo engine
    {:ok, echo_addr} = EngineSystem.API.spawn_engine(Examples.EnhancedEchoEngine, %{}, %{})

    IO.puts("📢 EchoEngine: #{inspect(echo_addr)}")

    # Send an echo request
    EngineSystem.API.send_message(echo_addr, {:echo, "Hello Engine World!"}, {0, 0})

    Process.sleep(1000)
    IO.puts("✅ Echo test complete!")
  end
end
