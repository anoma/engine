defmodule Examples.InteractiveDemo do
  @moduledoc """
  Interactive demo showcasing real engine interactions and message passing.

  This module demonstrates:
  1. Two engines communicating with each other (Ping-Pong engines)
  2. A GenServer sending messages to engines and getting responses
  3. An engine sending messages to a GenServer
  4. Visible effects when messages are processed

  Usage:
    iex> Examples.InteractiveDemo.start_demo()
    iex> Examples.InteractiveDemo.test_engine_to_engine()
    iex> Examples.InteractiveDemo.test_genserver_to_engine()
    iex> Examples.InteractiveDemo.test_engine_to_genserver()
  """

  use GenServer
  require Logger

  # State for the demo GenServer
  defstruct [:ping_engine_address, :pong_engine_address, :echo_engine_address, :messages_received]

  ## Public API

  def start_demo do
    IO.puts("\n🚀 Starting EngineSystem Interactive Demo...")

    # Start the EngineSystem if not already started
    case EngineSystem.API.start_system() do
      {:ok, _} ->
        IO.puts("✅ EngineSystem started successfully")

      {:error, {:already_started, _}} ->
        IO.puts("✅ EngineSystem already running")

      {:error, reason} ->
        IO.puts("❌ Failed to start EngineSystem: #{inspect(reason)}")
        {:error, reason}
    end

    # Start the demo GenServer
    case GenServer.start_link(__MODULE__, [], name: __MODULE__) do
      {:ok, _pid} ->
        IO.puts("✅ Demo GenServer started")
        spawn_demo_engines()

      {:error, {:already_started, _pid}} ->
        IO.puts("✅ Demo GenServer already running")
        :ok

      {:error, reason} ->
        IO.puts("❌ Failed to start Demo GenServer: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def test_engine_to_engine do
    IO.puts("\n🎾 Testing Engine-to-Engine Communication (Ping-Pong)")

    state = GenServer.call(__MODULE__, :get_state)

    if state.ping_engine_address && state.pong_engine_address do
      IO.puts("📤 Sending ping from PingEngine to PongEngine...")

      # Send ping message to the PongEngine
      result =
        EngineSystem.API.send_message(
          state.pong_engine_address,
          :ping,
          state.ping_engine_address
        )

      case result do
        :ok ->
          IO.puts("✅ Ping sent successfully!")
          IO.puts("👀 Watch the logs for pong response...")

        {:error, reason} ->
          IO.puts("❌ Failed to send ping: #{inspect(reason)}")
      end
    else
      IO.puts("❌ Engines not ready. Run start_demo() first.")
    end
  end

  def test_genserver_to_engine do
    IO.puts("\n📨 Testing GenServer-to-Engine Communication")

    state = GenServer.call(__MODULE__, :get_state)

    if state.echo_engine_address do
      IO.puts("📤 GenServer sending echo message to EchoEngine...")

      # Send echo message from this GenServer to the EchoEngine
      result =
        EngineSystem.API.send_message(
          state.echo_engine_address,
          {:echo, "Hello from GenServer!"},
          # System address instead of GenServer format
          {0, 0}
        )

      case result do
        :ok ->
          IO.puts("✅ Echo message sent successfully!")
          IO.puts("👀 Waiting for echo response...")
          wait_for_echo_response()

        {:error, reason} ->
          IO.puts("❌ Failed to send echo: #{inspect(reason)}")
      end
    else
      IO.puts("❌ Echo engine not ready. Run start_demo() first.")
    end
  end

  def test_engine_to_genserver do
    IO.puts("\n🔄 Testing Engine-to-GenServer Communication")

    state = GenServer.call(__MODULE__, :get_state)

    if state.echo_engine_address do
      IO.puts("📤 Triggering engine to send message to GenServer...")

      # Send a special message that will cause the engine to send back to this GenServer
      result =
        EngineSystem.API.send_message(
          state.echo_engine_address,
          {:notify_genserver, "Engine says hello!"},
          # System address instead of GenServer format
          {0, 0}
        )

      case result do
        :ok ->
          IO.puts("✅ Notification trigger sent!")
          IO.puts("👀 Waiting for engine notification...")
          wait_for_engine_notification()

        {:error, reason} ->
          IO.puts("❌ Failed to send notification trigger: #{inspect(reason)}")
      end
    else
      IO.puts("❌ Echo engine not ready. Run start_demo() first.")
    end
  end

  def status do
    state = GenServer.call(__MODULE__, :get_state)

    IO.puts("\n📊 Demo Status:")
    IO.puts("  🎯 Ping Engine: #{inspect(state.ping_engine_address)}")
    IO.puts("  🏓 Pong Engine: #{inspect(state.pong_engine_address)}")
    IO.puts("  📢 Echo Engine: #{inspect(state.echo_engine_address)}")
    IO.puts("  📨 Messages Received: #{state.messages_received}")

    # Get system info - it returns a map directly, not {:ok, map}
    system_info = EngineSystem.API.get_system_info()
    IO.puts("  🔧 Running Engines: #{system_info.running_instances}")
    IO.puts("  🏗️  Total Instances: #{system_info.total_instances}")
  end

  def stop_demo do
    IO.puts("\n🛑 Stopping demo...")
    GenServer.stop(__MODULE__)
    IO.puts("✅ Demo stopped")
  end

  ## GenServer Callbacks

  def init([]) do
    state = %__MODULE__{
      ping_engine_address: nil,
      pong_engine_address: nil,
      echo_engine_address: nil,
      messages_received: 0
    }

    {:ok, state}
  end

  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  def handle_call({:update_addresses, addresses}, _from, state) do
    new_state = %{
      state
      | ping_engine_address: addresses[:ping],
        pong_engine_address: addresses[:pong],
        echo_engine_address: addresses[:echo]
    }

    {:reply, :ok, new_state}
  end

  # Handle messages from engines
  def handle_info({:engine_message, from_address, payload}, state) do
    IO.puts(
      "\n🎉 GenServer received message from engine #{inspect(from_address)}: #{inspect(payload)}"
    )

    new_state = %{state | messages_received: state.messages_received + 1}
    {:noreply, new_state}
  end

  def handle_info(msg, state) do
    IO.puts("\n📨 GenServer received unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  ## Private Functions

  defp spawn_demo_engines do
    IO.puts("\n🏗️  Spawning demo engines...")

    # Spawn PingEngine
    ping_result = EngineSystem.API.spawn_engine(Examples.PingEngine, %{}, %{}, :ping_engine)

    # Spawn PongEngine
    pong_result = EngineSystem.API.spawn_engine(Examples.PongEngine, %{}, %{}, :pong_engine)

    # Spawn Enhanced EchoEngine
    echo_result =
      EngineSystem.API.spawn_engine(Examples.EnhancedEchoEngine, %{}, %{}, :echo_engine)

    case {ping_result, pong_result, echo_result} do
      {{:ok, ping_addr}, {:ok, pong_addr}, {:ok, echo_addr}} ->
        IO.puts("✅ All engines spawned successfully!")
        IO.puts("  🎯 PingEngine: #{inspect(ping_addr)}")
        IO.puts("  🏓 PongEngine: #{inspect(pong_addr)}")
        IO.puts("  📢 EchoEngine: #{inspect(echo_addr)}")

        # Update the PingEngine's target to point to PongEngine
        update_ping_target(ping_addr, pong_addr)

        # Store addresses
        GenServer.call(
          __MODULE__,
          {:update_addresses,
           %{
             ping: ping_addr,
             pong: pong_addr,
             echo: echo_addr
           }}
        )

        IO.puts("\n🎊 Demo setup complete! Try the test functions:")
        IO.puts("  Examples.InteractiveDemo.test_engine_to_engine()")
        IO.puts("  Examples.InteractiveDemo.test_genserver_to_engine()")
        IO.puts("  Examples.InteractiveDemo.test_engine_to_genserver()")

      _ ->
        IO.puts("❌ Failed to spawn engines:")
        IO.puts("  Ping: #{inspect(ping_result)}")
        IO.puts("  Pong: #{inspect(pong_result)}")
        IO.puts("  Echo: #{inspect(echo_result)}")
    end
  end

  defp update_ping_target(ping_addr, pong_addr) do
    # Send a configuration update to set the target
    EngineSystem.API.send_message(ping_addr, {:set_target, pong_addr}, {0, 0})
  end

  defp wait_for_echo_response do
    receive do
      {:engine_message, _from, payload} ->
        IO.puts("✅ Received echo response: #{inspect(payload)}")

      other ->
        IO.puts("📨 Received other message: #{inspect(other)}")
    after
      5000 ->
        IO.puts("⏰ Timeout waiting for echo response")
    end
  end

  defp wait_for_engine_notification do
    receive do
      {:engine_message, _from, payload} ->
        IO.puts("✅ Received engine notification: #{inspect(payload)}")

      other ->
        IO.puts("📨 Received other message: #{inspect(other)}")
    after
      5000 ->
        IO.puts("⏰ Timeout waiting for engine notification")
    end
  end
end
