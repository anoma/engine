use EngineSystem

defengine Examples.PongEngine do
  @moduledoc """
  I am a pong engine that demonstrates responsive communication patterns and
  serves as the counterpart to ping engines in distributed interaction protocols.

  ## My Purpose

  I serve as a dedicated responder in ping-pong communication protocols,
  demonstrating how engines can implement reliable, stateful response patterns
  for distributed system coordination and health checking.

  ## Communication Role

  I specialize in responsive communication:

  ### Ping Response Protocol
  I implement the server side of the ping-pong protocol:
  - I receive ping messages from other engines
  - I respond immediately with pong messages
  - I track the number of ping-pong interactions I've handled

  ### State Tracking
  I maintain internal metrics to monitor my activity:
  - `pong_count`: Number of ping messages I've responded to
  - This provides visibility into system activity and my responsiveness

  ## Message Interface

  I handle two primary message types:

  ### `:ping` Messages (Primary Function)
  When I receive a ping message, I:
  1. Increment my pong counter to track activity
  2. Send a pong response back to the sender
  3. Log the interaction for visibility and debugging

  ### `:pong` Messages (Graceful Handling)
  While I don't normally expect to receive pong messages (since I'm the responder),
  I handle them gracefully to prevent system errors and provide clear feedback
  about unexpected interactions.

  ## State Management

  I maintain simple but effective state tracking:
  - **Activity Counting**: I track how many ping requests I've handled
  - **Persistent State**: My counter persists across all message interactions
  - **Atomic Updates**: Each ping-pong cycle atomically updates my state

  ## Usage Examples

      # Spawn me
      {:ok, pong_addr} = EngineSystem.spawn_engine(Examples.PongEngine)

      # Other engines can ping me
      send_message(pong_addr, {:ping, %{}})

      # I'll automatically respond with pong and update my counter

  ## Design Patterns

  I demonstrate several important engine patterns:
  - **Responsive Design**: Immediate response to incoming requests
  - **State Persistence**: Maintaining counters across message interactions
  - **Graceful Error Handling**: Handling unexpected messages appropriately
  - **Activity Monitoring**: Tracking and logging system interactions
  - **Protocol Compliance**: Implementing standard ping-pong semantics

  ## Integration Scenarios

  I'm particularly useful in scenarios involving:
  - **Health Monitoring**: Providing reliable responses for health checks
  - **Load Testing**: Serving as a consistent responder for performance testing
  - **Protocol Testing**: Verifying ping-pong communication patterns
  - **Distributed Coordination**: Participating in coordination protocols
  - **System Diagnostics**: Providing feedback about message routing

  ## Reliability Features

  I'm designed for reliability and consistency:
  - **Always Responsive**: I always respond to valid ping messages
  - **State Consistency**: My counter accurately reflects my activity
  - **Error Resilience**: I handle unexpected messages without crashing
  - **Visibility**: I provide clear logging of all interactions

  ## Performance Characteristics

  I'm optimized for responsiveness:
  - **Low Latency**: Immediate response to ping messages
  - **Minimal State**: Simple counter-based state management
  - **Efficient Processing**: Direct message handling without complex logic

  I serve as both a practical utility for building responsive distributed
  systems and an educational example of how to implement reliable engine
  response patterns.
  """

  version("1.0.0")
  mode(:process)

  env do
    %{pong_count: 0}
  end

  interface do
    message(:ping)
    message(:pong)
  end

  behaviour do
    # Handle incoming ping (reply with pong)
    on_message :ping, _msg_payload, _config, env, sender do
      new_env = Map.put(env, :pong_count, env.pong_count + 1)

      IO.puts(
        "🏓 PongEngine: Received ping from #{inspect(sender)}, sending pong ##{new_env.pong_count}"
      )

      {:ok,
       [
         {:update_environment, new_env},
         {:send, sender, :pong}
       ]}
    end

    # Handle incoming pong (shouldn't normally happen but handle gracefully)
    on_message :pong, _msg_payload, _config, _env, sender do
      IO.puts("🤔 PongEngine: Received unexpected pong from #{inspect(sender)}")
      {:ok, []}
    end
  end
end
