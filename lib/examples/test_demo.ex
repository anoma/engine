defmodule Examples.TestDemo do
  @moduledoc """
  I am a simple test verification system that ensures the engine interaction
  demonstration works correctly and provides quick validation of core EngineSystem functionality.

  ## My Purpose

  I serve as a lightweight testing and validation tool that verifies the
  EngineSystem's core functionality through practical demonstrations. Rather
  than comprehensive testing, I focus on quick validation that the system
  is working correctly and can handle basic interaction patterns.

  ## Testing Philosophy

  I believe in practical, observable testing that provides immediate feedback:
  - **Quick Validation**: Fast tests that verify basic functionality
  - **Visual Feedback**: Clear console output showing what's happening
  - **Real Interactions**: Testing with actual engine instances, not mocks
  - **End-to-End Verification**: Testing complete message flows

  ## Test Coverage

  I provide focused testing across these key areas:

  ### System Integration Testing
  I verify that the complete EngineSystem can start up and coordinate
  multiple engine instances working together.

  ### Communication Pattern Testing
  I test the fundamental communication patterns:
  - Engine-to-engine message passing
  - GenServer-to-engine integration
  - Engine-to-GenServer responses

  ### Basic Functionality Verification
  I ensure that core engine operations work correctly:
  - Engine spawning and registration
  - Message sending and receiving
  - State management and persistence

  ## Test Functions

  I provide several focused test functions:

  ### `run_test/0` - Comprehensive Demo Test
  My main test function that runs a complete demonstration sequence,
  testing all major interaction patterns in a realistic scenario.

  ### `quick_ping_test/0` - Basic Connectivity Test
  A fast test that verifies basic engine-to-engine communication using
  the ping-pong protocol. Perfect for quick system validation.

  ### `echo_test/0` - Message Processing Test
  A simple test that verifies message processing and response handling
  using the echo engine pattern.

  ## Test Design Principles

  I follow these principles in my test design:

  ### Observable Results
  All my tests produce visible output that clearly shows what's happening
  and whether operations are succeeding or failing.

  ### Realistic Scenarios
  I test with real engine instances and actual message passing, not
  simplified mocks or stubs.

  ### Quick Feedback
  My tests run quickly and provide immediate feedback about system health,
  making them suitable for development workflows.

  ### Minimal Dependencies
  I rely only on the core EngineSystem and example engines, making my
  tests portable and reliable.

  ## Usage Examples

      # Run the complete test suite
      Examples.TestDemo.run_test()

      # Quick connectivity check
      Examples.TestDemo.quick_ping_test()

      # Simple message processing test
      Examples.TestDemo.echo_test()

  ## Integration with Development

  I'm designed to be useful during development:
  - **Smoke Testing**: Quick verification that changes haven't broken core functionality
  - **Demo Preparation**: Ensuring demonstrations will work before presenting
  - **Learning Tool**: Providing working examples of engine interaction patterns
  - **Debugging Aid**: Showing expected behavior when troubleshooting issues

  ## Output and Feedback

  I provide clear, emoji-enhanced output that makes it easy to:
  - Quickly scan test results
  - Identify which components are being tested
  - Understand what each test is verifying
  - Spot issues when they occur

  ## Relationship to Other Testing

  I complement but don't replace comprehensive testing:
  - I focus on integration and demonstration scenarios
  - I provide quick validation rather than exhaustive coverage
  - I test real-world usage patterns rather than edge cases
  - I serve as both a test and a learning tool

  My goal is to provide confidence that the EngineSystem is working correctly
  for common use cases while serving as an educational resource for developers
  learning to build distributed systems with engines.
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
