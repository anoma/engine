use EngineSystem

defengine Examples.EnhancedEchoEngine do
  @moduledoc """
  I am an enhanced echo engine that demonstrates advanced interaction patterns
  between engines and GenServers, showcasing visible effects and cross-process communication.

  ## My Capabilities

  I extend the basic echo functionality with sophisticated communication patterns:

  ### Engine-to-Engine Communication
  I handle standard engine message passing with proper effect generation,
  maintaining state and providing detailed logging of all interactions.

  ### GenServer Integration
  I can seamlessly communicate with GenServer processes, demonstrating how
  engines can integrate with traditional Elixir/OTP patterns:
  - I detect GenServer senders and adapt my response mechanism
  - I send direct Elixir messages to GenServer processes when appropriate
  - I maintain separate counters for different interaction types

  ### Visible Effects & Monitoring
  I provide comprehensive logging and state tracking:
  - Echo count tracking for performance monitoring
  - GenServer notification counting for integration metrics
  - Detailed console output for debugging and demonstration purposes

  ## State Management

  I maintain internal state to track my activity:
  - `echo_count`: Number of echo messages I've processed
  - `genserver_notifications`: Number of GenServer interactions I've handled

  ## Message Types

  ### Echo Messages (`:echo`)
  I process echo requests and adapt my response based on the sender type,
  ensuring proper message delivery whether the sender is an engine or GenServer.

  ### Ping-Pong Protocol (`:ping`, `:pong`)
  I implement the standard ping-pong protocol for testing connectivity
  and basic message flow verification.

  ### GenServer Notifications (`:notify_genserver`)
  I can send notifications to GenServer processes, demonstrating bidirectional
  communication between the engine system and traditional OTP processes.

  ## Usage Examples

      # Spawn me
      {:ok, enhanced_addr} = EngineSystem.spawn_engine(Examples.EnhancedEchoEngine)

      # Standard engine communication
      send_message(enhanced_addr, {:echo, %{content: "Hello from engine!"}})

      # GenServer integration (from within a GenServer)
      send_message(enhanced_addr, {:notify_genserver, %{message: "Hello from GenServer!"}})

  ## Design Patterns

  I demonstrate several important patterns:
  - **Adaptive Response**: I modify my behavior based on sender type
  - **State Tracking**: I maintain counters and metrics for monitoring
  - **Cross-Process Communication**: I bridge engine and GenServer worlds
  - **Effect Visibility**: I provide clear feedback about my operations

  My implementation serves as a reference for building engines that need to
  interact with existing Elixir/OTP applications while maintaining the benefits
  of the engine model.
  """

  version("1.0.0")
  mode(:process)

  env do
    %{
      echo_count: 0,
      genserver_notifications: 0
    }
  end

  interface do
    message(:echo, [:content])
    message(:ping)
    message(:pong)
    message(:notify_genserver, [:message])
  end

  behaviour do
    # Handle echo messages - echo back to sender
    on_message :echo, msg_payload, _config, env, sender do
      content = msg_payload[:content] || msg_payload
      new_env = Map.put(env, :echo_count, env.echo_count + 1)

      IO.puts("📢 EchoEngine: Echoing message ##{new_env.echo_count}: #{inspect(content)}")

      # Handle echo response based on sender type
      case sender do
        {:genserver, pid} when is_pid(pid) ->
          # Send echo response directly to GenServer
          send(pid, {:engine_message, self(), {:echo_response, content}})
          IO.puts("📢 EchoEngine: Sent echo response to GenServer #{inspect(pid)}")
          {:ok, [{:update_environment, new_env}]}

        engine_address ->
          # Send echo back to engine using standard effect
          {:ok,
           [
             {:update_environment, new_env},
             {:send, engine_address, {:echo_response, content}}
           ]}
      end
    end

    # Handle ping messages
    on_message :ping, _msg_payload, _config, env, sender do
      new_env = Map.put(env, :echo_count, env.echo_count + 1)
      IO.puts("📢 EchoEngine: Received ping, sending pong back")

      {:ok,
       [
         {:update_environment, new_env},
         {:send, sender, :pong}
       ]}
    end

    # Handle pong messages
    on_message :pong, _msg_payload, _config, _env, sender do
      IO.puts("🤔 EnhancedEchoEngine: Received unexpected pong from #{inspect(sender)}")
      {:ok, []}
    end

    # Handle GenServer notification requests
    on_message :notify_genserver, %{message: message}, _config, env, sender do
      new_env = Map.put(env, :genserver_notifications, env.genserver_notifications + 1)

      IO.puts(
        "📢 EchoEngine: Sending notification ##{new_env.genserver_notifications} to GenServer"
      )

      # For GenServer communication, we need to extract the PID from sender address
      # and send a regular Elixir message
      case sender do
        {:genserver, pid} when is_pid(pid) ->
          # Send a message directly to the GenServer process
          send(pid, {:engine_message, self(), {:engine_notification, message}})
          IO.puts("📢 EchoEngine: Sent message to GenServer #{inspect(pid)}")

        other ->
          IO.puts("📢 EchoEngine: Invalid GenServer sender: #{inspect(other)}")
      end

      {:ok, [{:update_environment, new_env}]}
    end
  end
end
