import EngineSystem.Engine.DSL

defengine Examples.SimpleEchoEngine do
  @moduledoc """
  Simple Echo Engine demonstrating default configuration behavior.

  This engine demonstrates what happens when you omit the configuration block
  in an engine definition. When no config block is provided, the DSL automatically
  applies default values:

  - `parent: nil` - No parent engine
  - `mode: :process` - Operates in process mode

  This is a minimal engine that simply echoes back any message it receives,
  making it useful for testing and demonstrating the default configuration
  behavior.

  ## Message Interface

  - `:echo` - Send a message to be echoed back
  - `:ping` - Simple ping message that returns `:pong`
  - `:get_stats` - Returns engine statistics

  ## Default Configuration Applied

  Since no `config` block is defined, the engine will automatically use:

  ```elixir
  config do
    %{
      parent: nil,
      mode: :process
    }
  end
  ```

  ## Example Usage

  ```elixir
  # Spawn the engine
  {:ok, address} = EngineSystem.spawn_engine(Examples.SimpleEchoEngine)

  # Send messages
  EngineSystem.send_message(address, {:echo, "Hello, World!"})
  EngineSystem.send_message(address, :ping)
  EngineSystem.send_message(address, :get_stats)
  ```
  """
  version("1.0.0")

  # Message interface - simple echo operations
  interface do
    # Echo back a message with its payload
    message(:echo, content: :any)
    # Simple ping-pong message
    message(:ping)
    # Get engine statistics
    message(:get_stats)
    # Response messages
    message(:echo_response, content: :any)
    message(:pong)
    message(:stats_response, message_count: :integer, echo_count: :integer)
  end

  # NOTE: No config block defined here!
  # This demonstrates the default configuration behavior.
  # The DSL will automatically apply:
  # config do
  #   %{
  #     parent: nil,
  #     mode: :process
  #   }
  # end

  # Environment to track simple statistics
  environment echo_env: %{message_count: 0, echo_count: 0} do
    field(:message_count, default: 0, type: :integer)
    field(:echo_count, default: 0, type: :integer)
  end

  # Accept all messages (no filtering needed for this simple engine)
  message_filter(fn _msg, _config, _env -> true end)

  # Behavior implementing echo functionality
  behaviour do
    # Echo operation - return the received content
    on_message :echo do
      quote do
        # Extract content from message payload
        content =
          case msg_payload do
            {content} -> content
            content -> content
          end

        # Update statistics
        current_message_count = get_in(env_data.local_state, [:message_count]) || 0
        current_echo_count = get_in(env_data.local_state, [:echo_count]) || 0

        new_local_state = %{
          message_count: current_message_count + 1,
          echo_count: current_echo_count + 1
        }

        new_env = %{env_data | local_state: new_local_state}

        # Create effects: update environment and send echo response
        effects = [{:update_environment, new_env}]

        # Add echo response if we have a sender
        final_effects =
          if msg_sender_address do
            effects ++ [{:send, msg_sender_address, {:echo_response, content}}]
          else
            effects
          end

        {:ok, final_effects}
      end
    end

    # Ping operation - simple ping-pong
    on_message :ping do
      quote do
        # Update message count
        current_message_count = get_in(env_data.local_state, [:message_count]) || 0
        current_echo_count = get_in(env_data.local_state, [:echo_count]) || 0

        new_local_state = %{
          message_count: current_message_count + 1,
          echo_count: current_echo_count
        }

        new_env = %{env_data | local_state: new_local_state}

        # Create effects: update environment and send pong
        effects = [{:update_environment, new_env}]

        # Add pong response if we have a sender
        final_effects =
          if msg_sender_address do
            effects ++ [{:send, msg_sender_address, :pong}]
          else
            effects
          end

        {:ok, final_effects}
      end
    end

    # Get stats operation - return current statistics
    on_message :get_stats do
      quote do
        # Get current statistics
        message_count = get_in(env_data.local_state, [:message_count]) || 0
        echo_count = get_in(env_data.local_state, [:echo_count]) || 0

        # Update message count (getting stats counts as receiving a message)
        new_local_state = %{
          message_count: message_count + 1,
          echo_count: echo_count
        }

        new_env = %{env_data | local_state: new_local_state}

        # Create effects: update environment and send stats
        effects = [{:update_environment, new_env}]

        # Add stats response if we have a sender
        final_effects =
          if msg_sender_address do
            effects ++
              [{:send, msg_sender_address, {:stats_response, message_count + 1, echo_count}}]
          else
            effects
          end

        {:ok, final_effects}
      end
    end
  end
end
