use EngineSystem

defengine Examples.DiagramDemoEngine, generate_diagrams: true do
  @moduledoc """
  I am a demonstration engine that showcases automatic Mermaid diagram generation.

  This engine demonstrates various communication patterns that will be automatically
  documented in generated sequence diagrams:

  - Client-to-Engine messaging
  - Engine-to-Engine communication
  - State management with environment updates
  - Different types of message handlers and effects

  ## Generated Diagrams

  When compiled with `generate_diagrams: true`, this engine will automatically
  generate Mermaid sequence diagrams showing:

  1. **Individual Engine Diagram**: Shows all message flows for this specific engine
  2. **System Interaction Diagram**: Shows how this engine interacts with other engines

  ## Communication Patterns Demonstrated

  ### Direct Response Pattern
  - `:ping` messages receive immediate `:pong` responses
  - Shows synchronous communication flow

  ### Forwarding Pattern  
  - `:forward_message` demonstrates message relay to another engine
  - Shows how engines can act as intermediaries

  ### State Update Pattern
  - `:increment` shows state changes with environment updates
  - Demonstrates stateful engine behavior

  ### Broadcast Pattern
  - `:broadcast` sends messages to multiple targets
  - Shows one-to-many communication

  ## Usage

  To see the generated diagrams, compile this engine and check the `docs/diagrams/` folder.

      # The diagrams are automatically generated during compilation
      # Check docs/diagrams/DiagramDemo.md for the individual engine diagram
      # Check docs/diagrams/system_interaction.md for system-wide interactions
  """

  version("1.0.0")
  mode(:process)

  env do
    %{
      counter: 0,
      targets: [],
      last_sender: nil
    }
  end

  config do
    %{
      max_forwards: 3,
      broadcast_enabled: true,
      default_targets: []
    }
  end

  interface do
    # Basic ping-pong pattern
    message(:ping)
    message(:pong)

    # State management
    message(:increment)
    message(:get_counter)
    message(:counter_value, [:value])

    # Forwarding and routing
    message(:forward_message, [:target, :payload])
    message(:set_targets, [:targets])

    # Broadcasting
    message(:broadcast, [:message])

    # Engine lifecycle
    message(:reset)
    message(:status)
    message(:status_response, [:counter, :targets, :last_sender])
  end

  behaviour do
    # Simple ping-pong response - demonstrates direct response pattern
    on_message :ping, _msg_payload, _config, env, sender do
      IO.puts("🏓 DiagramDemo: Received ping from #{inspect(sender)}, sending pong")

      new_env = %{env | last_sender: sender}

      {:ok,
       [
         {:update_environment, new_env},
         {:send, sender, :pong}
       ]}
    end

    # Handle pong responses
    on_message :pong, _msg_payload, _config, env, sender do
      IO.puts("🎉 DiagramDemo: Received pong from #{inspect(sender)}")
      {:ok, []}
    end

    # State management - demonstrates environment updates
    on_message :increment, _msg_payload, _config, env, sender do
      new_counter = env.counter + 1
      new_env = %{env | counter: new_counter, last_sender: sender}

      IO.puts("📊 DiagramDemo: Counter incremented to #{new_counter}")

      {:ok,
       [
         {:update_environment, new_env},
         {:send, sender, {:counter_value, new_counter}}
       ]}
    end

    # Query state
    on_message :get_counter, _msg_payload, _config, env, sender do
      {:ok,
       [
         {:send, sender, {:counter_value, env.counter}}
       ]}
    end

    # Handle counter value responses (when we query other engines)
    on_message :counter_value, %{value: value}, _config, _env, sender do
      IO.puts("📈 DiagramDemo: Received counter value #{value} from #{inspect(sender)}")
      {:ok, []}
    end

    # Message forwarding - demonstrates engine-to-engine communication
    on_message :forward_message, %{target: target, payload: payload}, config, env, sender do
      if env.counter < config.max_forwards do
        new_env = %{env | counter: env.counter + 1, last_sender: sender}

        IO.puts(
          "📨 DiagramDemo: Forwarding #{inspect(payload)} to #{inspect(target)} (#{new_env.counter}/#{config.max_forwards})"
        )

        {:ok,
         [
           {:update_environment, new_env},
           {:send, target, payload}
         ]}
      else
        IO.puts("⚠️  DiagramDemo: Max forwards reached, dropping message")

        {:ok,
         [
           {:send, sender, {:error, :max_forwards_reached}}
         ]}
      end
    end

    # Set communication targets
    on_message :set_targets, %{targets: targets}, _config, env, sender do
      new_env = %{env | targets: targets, last_sender: sender}
      IO.puts("🎯 DiagramDemo: Targets set to #{inspect(targets)}")

      {:ok,
       [
         {:update_environment, new_env},
         {:send, sender, :ack}
       ]}
    end

    # Broadcasting - demonstrates one-to-many communication
    on_message :broadcast, %{message: message}, config, env, sender do
      if config.broadcast_enabled and length(env.targets) > 0 do
        new_env = %{env | last_sender: sender}

        # Create send effects for each target
        send_effects =
          env.targets
          |> Enum.map(fn target ->
            {:send, target, message}
          end)

        IO.puts(
          "📡 DiagramDemo: Broadcasting #{inspect(message)} to #{length(env.targets)} targets"
        )

        effects =
          [
            {:update_environment, new_env},
            {:send, sender, {:broadcast_sent, length(env.targets)}}
          ] ++ send_effects

        {:ok, effects}
      else
        IO.puts("⚠️  DiagramDemo: Broadcasting disabled or no targets set")

        {:ok,
         [
           {:send, sender, {:error, :broadcast_unavailable}}
         ]}
      end
    end

    # Reset engine state
    on_message :reset, _msg_payload, _config, _env, sender do
      IO.puts("🔄 DiagramDemo: Resetting state")

      reset_env = %{
        counter: 0,
        targets: [],
        last_sender: sender
      }

      {:ok,
       [
         {:update_environment, reset_env},
         {:send, sender, :reset_complete}
       ]}
    end

    # Status query
    on_message :status, _msg_payload, _config, env, sender do
      response = %{
        counter: env.counter,
        targets: env.targets,
        last_sender: env.last_sender
      }

      {:ok,
       [
         {:send, sender, {:status_response, response}}
       ]}
    end

    # Handle status responses from other engines
    on_message :status_response, status_data, _config, _env, sender do
      IO.puts("📋 DiagramDemo: Received status from #{inspect(sender)}: #{inspect(status_data)}")
      {:ok, []}
    end
  end
end
