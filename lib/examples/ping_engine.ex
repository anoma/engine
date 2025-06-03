use EngineSystem

defengine Examples.PingEngine do
  @moduledoc """
  I am a ping engine that demonstrates active message sending and target-based
  communication patterns within the EngineSystem architecture.

  ## My Purpose

  I serve as an active communication engine that can initiate conversations with
  other engines, demonstrating how engines can maintain ongoing relationships
  and coordinate distributed interactions.

  ## Communication Patterns

  I implement several key communication patterns:

  ### Target-Based Messaging
  I maintain a configurable target address and can send messages to that target
  on command. This demonstrates how engines can maintain persistent relationships
  with other system components.

  ### Ping-Pong Protocol
  I implement both sides of the ping-pong protocol:
  - I can send ping messages to my configured target
  - I can respond to incoming ping messages with pong responses
  - I can handle pong responses from other engines

  ### State Tracking
  I maintain internal counters to track my activity:
  - `ping_count`: Number of ping operations I've performed
  - `target`: Current target address for my outgoing messages

  ## Message Interface

  I handle four primary message types:

  ### `:set_target` Messages
  Configure my target address for outgoing communications. This allows other
  engines or system components to dynamically configure my behavior.

  ### `:send_ping` Messages
  Trigger me to send a ping message to my configured target. I increment my
  ping counter and send the ping if a target is configured.

  ### `:ping` Messages (Incoming)
  Handle incoming ping messages by responding with a pong. I increment my
  counter and send a pong response back to the sender.

  ### `:pong` Messages (Incoming)
  Handle pong responses from other engines. I log the successful completion
  of a ping-pong cycle.

  ## State Management

  I maintain persistent state across message interactions:
  - **Target Tracking**: I remember my configured target between messages
  - **Activity Counting**: I track the number of ping operations I've performed
  - **Dynamic Configuration**: My target can be updated at runtime

  ## Usage Examples

      # Spawn me
      {:ok, ping_addr} = EngineSystem.spawn_engine(Examples.PingEngine)

      # Configure my target (another engine address)
      send_message(ping_addr, {:set_target, %{target_address: other_engine_addr}})

      # Trigger me to send a ping
      send_message(ping_addr, {:send_ping, %{}})

      # I can also respond to incoming pings
      send_message(ping_addr, {:ping, %{}})

  ## Design Patterns

  I demonstrate several important engine patterns:
  - **Active Communication**: Initiating conversations rather than just responding
  - **Target Management**: Maintaining relationships with other system components
  - **State Persistence**: Keeping track of configuration and activity across messages
  - **Protocol Implementation**: Implementing both sides of a communication protocol
  - **Conditional Logic**: Only sending messages when properly configured

  ## Integration Scenarios

  I'm particularly useful in scenarios involving:
  - **Health Checking**: Regularly pinging other engines to verify connectivity
  - **Coordination Protocols**: Implementing distributed coordination algorithms
  - **Testing Infrastructure**: Verifying message routing and engine responsiveness
  - **Demonstration Systems**: Showing how engines can actively communicate

  ## Visibility & Debugging

  I provide comprehensive logging of all my activities, making it easy to
  observe and debug distributed communication patterns. My console output
  clearly shows when I send pings, receive responses, and update my configuration.

  I serve as both a practical utility for building distributed systems and
  an educational example of active engine communication patterns.
  """

  version("1.0.0")
  mode(:process)

  env do
    %{
      ping_count: 0,
      target: nil
    }
  end

  interface do
    message(:ping)
    message(:pong)
    message(:set_target, [:target_address])
    message(:send_ping)
  end

  behaviour do
    # Handle configuration update for target
    on_message :set_target, %{target_address: target}, _config, env, _sender do
      new_env = Map.put(env, :target, target)
      IO.puts("🎯 PingEngine: Target set to #{inspect(target)}")
      {:ok, [{:update_environment, new_env}]}
    end

    # Handle send_ping command
    on_message :send_ping, _msg_payload, _config, env, _sender do
      if env.target do
        new_env = Map.put(env, :ping_count, env.ping_count + 1)
        IO.puts("🏓 PingEngine: Sending ping ##{new_env.ping_count} to #{inspect(env.target)}")

        {:ok,
         [
           {:update_environment, new_env},
           {:send, env.target, :ping}
         ]}
      else
        IO.puts("❌ PingEngine: No target configured")
        {:ok, []}
      end
    end

    # Handle incoming ping (reply with pong)
    on_message :ping, _msg_payload, _config, env, sender do
      new_env = Map.put(env, :ping_count, env.ping_count + 1)
      IO.puts("🏓 PingEngine: Received ping from #{inspect(sender)}, sending pong back")

      {:ok,
       [
         {:update_environment, new_env},
         {:send, sender, :pong}
       ]}
    end

    # Handle incoming pong
    on_message :pong, _msg_payload, _config, _env, sender do
      IO.puts("🎉 PingEngine: Received pong from #{inspect(sender)}!")
      {:ok, []}
    end
  end
end
