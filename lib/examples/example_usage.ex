defmodule Examples.Usage do
  @moduledoc """
  Example usage demonstrating the KV Store Engine and Priority Chat Engine.

  This module shows how to:
  1. Start the EngineSystem
  2. Spawn engine instances
  3. Send messages between engines
  4. Demonstrate mailbox filtering and customization
  5. Show dynamic filter updates
  """

  alias EngineSystem
  alias Examples.{KVStoreEngine, PriorityChatEngine, TickerEngine}

  @doc """
  Demonstrates the KV Store Engine functionality.

  Shows:
  - Basic CRUD operations
  - Access mode restrictions
  - Store size limits
  - Access count tracking
  """
  def demo_kv_store do
    IO.puts("=== KV Store Engine Demo ===")

    # Start the system
    {:ok, _} = EngineSystem.start()

    # Spawn a KV store with default configuration
    {:ok, store_address} = EngineSystem.spawn_engine(Examples.KVStoreEngine)
    IO.puts("Spawned KV store at address: #{inspect(store_address)}")

    # Spawn a read-only KV store
    readonly_config = %{access_mode: :read_only, max_size: 5}
    {:ok, readonly_address} = EngineSystem.spawn_engine(Examples.KVStoreEngine, readonly_config)
    IO.puts("Spawned read-only KV store at address: #{inspect(readonly_address)}")

    # Spawn a client engine to interact with the stores
    {:ok, client_address} = EngineSystem.spawn_engine(Examples.KVStoreEngine)
    IO.puts("Spawned client at address: #{inspect(client_address)}")

    # Demonstrate basic operations
    IO.puts("\n--- Basic Operations ---")

    # Put some values
    :ok = EngineSystem.send_message(store_address, {:put, :name, "Alice"}, client_address)
    :ok = EngineSystem.send_message(store_address, {:put, :age, 30}, client_address)
    :ok = EngineSystem.send_message(store_address, {:put, :city, "New York"}, client_address)

    # Get values
    :ok = EngineSystem.send_message(store_address, {:get, :name}, client_address)
    :ok = EngineSystem.send_message(store_address, {:get, :age}, client_address)
    :ok = EngineSystem.send_message(store_address, {:get, :nonexistent}, client_address)

    # Try operations on read-only store
    IO.puts("\n--- Read-Only Store Operations ---")
    :ok = EngineSystem.send_message(readonly_address, {:put, :test, "value"}, client_address)
    :ok = EngineSystem.send_message(readonly_address, {:get, :test}, client_address)

    # Delete operation
    IO.puts("\n--- Delete Operations ---")
    :ok = EngineSystem.send_message(store_address, {:delete, :city}, client_address)
    :ok = EngineSystem.send_message(store_address, {:get, :city}, client_address)

    # Give time for messages to process
    Process.sleep(1000)

    # Get system info
    info = EngineSystem.get_system_info()
    IO.puts("\nSystem info: #{inspect(info)}")

    :ok
  end

  @doc """
  Demonstrates the Priority Chat Engine functionality.

  Shows:
  - Room management
  - Priority message filtering
  - Dynamic filter updates based on status
  - Message broadcasting
  """
  def demo_priority_chat do
    IO.puts("\n=== Priority Chat Engine Demo ===")

    # Start the system if not already started
    case EngineSystem.start() do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
    end

    # Spawn chat engines for different users
    {:ok, alice_address} =
      EngineSystem.spawn_engine(Examples.PriorityChatEngine, nil, nil, :alice)

    {:ok, bob_address} = EngineSystem.spawn_engine(Examples.PriorityChatEngine, nil, nil, :bob)

    {:ok, charlie_address} =
      EngineSystem.spawn_engine(Examples.PriorityChatEngine, nil, nil, :charlie)

    IO.puts("Spawned chat engines:")
    IO.puts("  Alice: #{inspect(alice_address)}")
    IO.puts("  Bob: #{inspect(bob_address)}")
    IO.puts("  Charlie: #{inspect(charlie_address)}")

    # Demonstrate room management
    IO.puts("\n--- Room Management ---")

    # Alice and Bob join a room
    :ok = EngineSystem.send_message(alice_address, {:join_room, :general, :alice})
    :ok = EngineSystem.send_message(bob_address, {:join_room, :general, :bob})

    # Send normal priority messages
    IO.puts("\n--- Normal Priority Messages ---")

    :ok =
      EngineSystem.send_message(
        alice_address,
        {:send_message, :general, "Hello everyone!", :normal}
      )

    :ok = EngineSystem.send_message(bob_address, {:send_message, :general, "Hi Alice!", :normal})

    # Demonstrate status changes and filtering
    IO.puts("\n--- Status Changes and Filtering ---")

    # Set Bob to busy status
    :ok = EngineSystem.send_message(bob_address, {:set_status, :busy})

    # Send messages with different priorities to busy Bob
    :ok =
      EngineSystem.send_message(
        bob_address,
        {:send_message, :general, "Normal message to busy Bob", :normal}
      )

    :ok =
      EngineSystem.send_message(
        bob_address,
        {:send_message, :general, "Urgent message to busy Bob", :urgent}
      )

    :ok =
      EngineSystem.send_message(
        bob_address,
        {:private_message, :bob, "Urgent private message", :urgent}
      )

    # Set Charlie to away status
    :ok = EngineSystem.send_message(charlie_address, {:set_status, :away})

    # Try sending messages to away Charlie
    :ok =
      EngineSystem.send_message(
        charlie_address,
        {:send_message, :general, "Normal message to away Charlie", :normal}
      )

    :ok =
      EngineSystem.send_message(
        charlie_address,
        {:private_message, :charlie, "Urgent private to away Charlie", :urgent}
      )

    # Check statuses
    IO.puts("\n--- Status Queries ---")
    :ok = EngineSystem.send_message(alice_address, {:get_status, nil}, alice_address)
    :ok = EngineSystem.send_message(bob_address, {:get_status, nil}, alice_address)
    :ok = EngineSystem.send_message(charlie_address, {:get_status, nil}, alice_address)

    # Demonstrate room leaving
    IO.puts("\n--- Room Management (Leaving) ---")
    :ok = EngineSystem.send_message(bob_address, {:leave_room, :general, :bob})

    # Give time for messages to process
    Process.sleep(1000)

    # Get system info
    info = EngineSystem.get_system_info()
    IO.puts("\nSystem info: #{inspect(info)}")

    :ok
  end

  @doc """
  Demonstrates advanced mailbox customization scenarios.

  Shows:
  - Custom filter functions
  - Dynamic filter updates
  - Filter behavior under different conditions
  """
  def demo_mailbox_customization do
    IO.puts("\n=== Mailbox Customization Demo ===")

    # Start the system if not already started
    case EngineSystem.start() do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
    end

    # Spawn a chat engine with custom configuration
    custom_config = %{
      max_rooms: 3,
      max_room_size: 2,
      priority_filtering: true,
      status: :available
    }

    {:ok, custom_address} = EngineSystem.spawn_engine(Examples.PriorityChatEngine, custom_config)
    IO.puts("Spawned custom chat engine: #{inspect(custom_address)}")

    # Test filter behavior in different states
    IO.puts("\n--- Testing Filter Behavior ---")

    # Available state - should accept all messages
    IO.puts("Testing AVAILABLE state (should accept all):")

    :ok =
      EngineSystem.send_message(custom_address, {:send_message, :test, "Normal message", :normal})

    :ok =
      EngineSystem.send_message(custom_address, {:send_message, :test, "Urgent message", :urgent})

    :ok = EngineSystem.send_message(custom_address, {:broadcast, :test, "Broadcast message"})

    # Change to busy state
    :ok = EngineSystem.send_message(custom_address, {:set_status, :busy})

    IO.puts("Testing BUSY state (should filter by priority):")

    :ok =
      EngineSystem.send_message(custom_address, {:send_message, :test, "Normal to busy", :normal})

    :ok =
      EngineSystem.send_message(custom_address, {:send_message, :test, "Urgent to busy", :urgent})

    :ok = EngineSystem.send_message(custom_address, {:broadcast, :test, "Broadcast to busy"})
    # System message
    :ok = EngineSystem.send_message(custom_address, {:join_room, :test, :user1})

    # Change to away state
    :ok = EngineSystem.send_message(custom_address, {:set_status, :away})

    IO.puts("Testing AWAY state (should only accept urgent private and system):")

    :ok =
      EngineSystem.send_message(custom_address, {:send_message, :test, "Normal to away", :normal})

    :ok =
      EngineSystem.send_message(
        custom_address,
        {:private_message, :user, "Normal private to away", :normal}
      )

    :ok =
      EngineSystem.send_message(
        custom_address,
        {:private_message, :user, "Urgent private to away", :urgent}
      )

    # System message
    :ok = EngineSystem.send_message(custom_address, {:get_status, nil})

    # Test configuration limits
    IO.puts("\n--- Testing Configuration Limits ---")

    # Set back to available for testing
    :ok = EngineSystem.send_message(custom_address, {:set_status, :available})

    # Try to exceed room limits (max_rooms: 3, max_room_size: 2)
    :ok = EngineSystem.send_message(custom_address, {:join_room, :room1, :user1})
    :ok = EngineSystem.send_message(custom_address, {:join_room, :room1, :user2})
    # Should fail - room full
    :ok = EngineSystem.send_message(custom_address, {:join_room, :room1, :user3})

    :ok = EngineSystem.send_message(custom_address, {:join_room, :room2, :user1})
    :ok = EngineSystem.send_message(custom_address, {:join_room, :room3, :user1})
    # Should fail - too many rooms
    :ok = EngineSystem.send_message(custom_address, {:join_room, :room4, :user1})

    # Give time for messages to process
    Process.sleep(1000)

    IO.puts("\nMailbox customization demo completed!")

    :ok
  end

  @doc """
  Demonstrates the Ticker Engine functionality.

  Shows:
  - Basic tick operations
  - Count setting with value constraints
  - Counter state management
  - Configuration limits (max/min values)
  """
  def demo_ticker do
    IO.puts("\n=== Ticker Engine Demo ===")

    # Start the system if not already started
    case EngineSystem.start() do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
    end

    # Spawn a ticker with default configuration
    {:ok, ticker_address} = EngineSystem.spawn_engine(Examples.TickerEngine)
    IO.puts("Spawned ticker at address: #{inspect(ticker_address)}")

    # Spawn a ticker with custom configuration
    custom_config = %{max_value: 10, min_value: -5, auto_reset: true}
    {:ok, custom_ticker_address} = EngineSystem.spawn_engine(Examples.TickerEngine, custom_config)
    IO.puts("Spawned custom ticker at address: #{inspect(custom_ticker_address)}")

    # Spawn a client engine to interact with the tickers
    {:ok, client_address} = EngineSystem.spawn_engine(Examples.TickerEngine)
    IO.puts("Spawned client at address: #{inspect(client_address)}")

    # Demonstrate basic operations
    IO.puts("\n--- Basic Tick Operations ---")

    # Get initial count
    :ok = EngineSystem.send_message(ticker_address, :get_count, client_address)

    # Perform some ticks
    :ok = EngineSystem.send_message(ticker_address, :tick, client_address)
    :ok = EngineSystem.send_message(ticker_address, :tick, client_address)
    :ok = EngineSystem.send_message(ticker_address, :tick, client_address)

    # Get count after ticks
    :ok = EngineSystem.send_message(ticker_address, :get_count, client_address)

    # Demonstrate count setting
    IO.puts("\n--- Count Setting Operations ---")

    # Set count to specific value
    :ok = EngineSystem.send_message(ticker_address, {:count, 42}, client_address)
    :ok = EngineSystem.send_message(ticker_address, :get_count, client_address)

    # Set count to another value
    :ok = EngineSystem.send_message(ticker_address, {:count, 100}, client_address)
    :ok = EngineSystem.send_message(ticker_address, :get_count, client_address)

    # Demonstrate reset operation
    IO.puts("\n--- Reset Operations ---")
    :ok = EngineSystem.send_message(ticker_address, :reset, client_address)
    :ok = EngineSystem.send_message(ticker_address, :get_count, client_address)

    # Demonstrate custom ticker with limits
    IO.puts("\n--- Custom Ticker with Limits ---")

    # Get initial count
    :ok = EngineSystem.send_message(custom_ticker_address, :get_count, client_address)

    # Tick up to the limit
    for _i <- 1..12 do
      :ok = EngineSystem.send_message(custom_ticker_address, :tick, client_address)
    end

    # Should auto-reset after exceeding max_value (10)
    :ok = EngineSystem.send_message(custom_ticker_address, :get_count, client_address)

    # Test setting values outside limits
    IO.puts("\n--- Testing Value Constraints ---")

    # Try to set value above max (should be clamped to 10)
    :ok = EngineSystem.send_message(custom_ticker_address, {:count, 50}, client_address)
    :ok = EngineSystem.send_message(custom_ticker_address, :get_count, client_address)

    # Try to set value below min (should be clamped to -5)
    :ok = EngineSystem.send_message(custom_ticker_address, {:count, -20}, client_address)
    :ok = EngineSystem.send_message(custom_ticker_address, :get_count, client_address)

    # Test invalid value
    IO.puts("\n--- Testing Invalid Operations ---")
    :ok = EngineSystem.send_message(ticker_address, {:count, "invalid"}, client_address)

    # Give time for messages to process
    Process.sleep(1000)

    # Get system info
    info = EngineSystem.get_system_info()
    IO.puts("\nSystem info: #{inspect(info)}")

    :ok
  end

  @doc """
  Runs all demos in sequence.
  """
  def run_all_demos do
    IO.puts("Starting EngineSystem Examples")
    IO.puts("=" |> String.duplicate(50))

    demo_kv_store()
    demo_priority_chat()
    demo_ticker()
    demo_mailbox_customization()

    IO.puts(("\n" <> "=") |> String.duplicate(50))
    IO.puts("All demos completed!")

    # Clean up
    EngineSystem.stop()
  end

  @doc """
  Interactive demo that allows manual testing.
  """
  def interactive_demo do
    IO.puts("=== Interactive Demo ===")
    IO.puts("Starting EngineSystem...")

    {:ok, _} = EngineSystem.start()

    # Spawn engines
    {:ok, kv_address} = EngineSystem.spawn_engine(KVStoreEngine, nil, nil, :kv_store)
    {:ok, chat_address} = EngineSystem.spawn_engine(PriorityChatEngine, nil, nil, :chat_engine)
    {:ok, ticker_address} = EngineSystem.spawn_engine(TickerEngine, nil, nil, :ticker)

    IO.puts("Engines spawned:")
    IO.puts("  KV Store: #{inspect(kv_address)} (name: :kv_store)")
    IO.puts("  Chat Engine: #{inspect(chat_address)} (name: :chat_engine)")
    IO.puts("  Ticker: #{inspect(ticker_address)} (name: :ticker)")

    IO.puts("\nYou can now interact with the engines using:")
    IO.puts("  EngineSystem.send_message(address, message)")
    IO.puts("  EngineSystem.lookup_address_by_name(:kv_store)")
    IO.puts("  EngineSystem.lookup_address_by_name(:chat_engine)")
    IO.puts("  EngineSystem.lookup_address_by_name(:ticker)")
    IO.puts("\nExample messages:")
    IO.puts("  KV Store: {:put, :key, \"value\"}, {:get, :key}, {:delete, :key}")
    IO.puts("  Chat: {:join_room, :general, :user1}, {:set_status, :busy}")
    IO.puts("  Ticker: :tick, {:count, 42}, :get_count, :reset")

    IO.puts("\nPress Enter to continue or 'q' to quit...")

    case IO.gets("") |> String.trim() do
      "q" ->
        EngineSystem.stop()
        IO.puts("Demo stopped.")

      _ ->
        IO.puts("Engines are running. Use IEx to interact with them.")
        IO.puts("Call Examples.Usage.interactive_demo() again to see this help.")
    end
  end
end
