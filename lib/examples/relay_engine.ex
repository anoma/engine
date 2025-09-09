use EngineSystem

defengine Examples.RelayEngine do
  @moduledoc """
  I am a relay engine that works with DiagramDemoEngine to demonstrate
  inter-engine communication patterns in generated Mermaid diagrams.

  This engine acts as a communication hub that can:
  - Relay messages between engines
  - Aggregate responses from multiple engines
  - Demonstrate complex multi-hop communication patterns
  """

  version("1.0.0")
  mode(:process)

  env do
    %{
      relay_targets: [],
      message_count: 0,
      pending_responses: %{},
      last_relay_time: nil
    }
  end

  config do
    %{
      max_pending: 10,
      relay_timeout: 5000,
      auto_relay_enabled: true
    }
  end

  interface do
    # Relay operations
    message(:relay_to, [:target, :message])
    message(:set_relay_targets, [:targets])
    message(:multi_relay, [:message])

    # Aggregation operations
    message(:gather_responses, [:targets, :query])
    message(:response_collected, [:source, :response])

    # Enhanced echo
    message(:enhanced_echo, [:data])
    message(:echo_response, [:original_data, :metadata])

    # Status and control
    message(:get_relay_stats)
    message(:relay_stats, [:message_count, :pending_count, :targets])
    message(:clear_pending)

    # Standard messages
    message(:ping)
    message(:pong)
    message(:ack)
  end

  behaviour do
    # Set relay targets for message forwarding
    on_message :set_relay_targets, %{targets: targets}, _config, env, sender do
      new_env = %{env | relay_targets: targets}
      IO.puts("🎯 RelayEngine: Relay targets set to #{inspect(targets)}")

      {:ok,
       [
         {:update_environment, new_env},
         {:send, sender, :ack}
       ]}
    end

    # Relay a message to a specific target
    on_message :relay_to, %{target: target, message: message}, _config, env, sender do
      new_count = env.message_count + 1

      new_env = %{
        env
        | message_count: new_count,
          last_relay_time: DateTime.utc_now()
      }

      IO.puts("📨 RelayEngine: Relaying #{inspect(message)} to #{inspect(target)} (#{new_count})")

      {:ok,
       [
         {:update_environment, new_env},
         {:send, target, message},
         {:send, sender, {:relay_sent, target, new_count}}
       ]}
    end

    # Multi-relay: send message to all configured targets
    on_message :multi_relay, %{message: message}, config, env, sender do
      if config.auto_relay_enabled and length(env.relay_targets) > 0 do
        new_count = env.message_count + length(env.relay_targets)

        new_env = %{
          env
          | message_count: new_count,
            last_relay_time: DateTime.utc_now()
        }

        # Create relay effects for each target
        relay_effects =
          env.relay_targets
          |> Enum.map(fn target ->
            {:send, target, message}
          end)

        IO.puts(
          "📡 RelayEngine: Multi-relaying #{inspect(message)} to #{length(env.relay_targets)} targets"
        )

        effects =
          [
            {:update_environment, new_env},
            {:send, sender, {:multi_relay_sent, length(env.relay_targets)}}
          ] ++ relay_effects

        {:ok, effects}
      else
        {:ok,
         [
           {:send, sender, {:error, :relay_disabled_or_no_targets}}
         ]}
      end
    end

    # Gather responses from multiple targets
    on_message :gather_responses, %{targets: targets, query: query}, config, env, sender do
      if length(targets) <= config.max_pending do
        # Generate unique request ID
        request_id = :crypto.strong_rand_bytes(8) |> Base.encode16()

        # Track pending responses
        new_pending =
          Map.put(env.pending_responses, request_id, %{
            requester: sender,
            targets: targets,
            responses: [],
            expected_count: length(targets)
          })

        new_env = %{env | pending_responses: new_pending}

        # Send queries to all targets
        query_effects =
          targets
          |> Enum.map(fn target ->
            {:send, target, {query, request_id}}
          end)

        IO.puts(
          "🔍 RelayEngine: Gathering responses from #{length(targets)} targets (req: #{request_id})"
        )

        effects =
          [
            {:update_environment, new_env}
          ] ++ query_effects

        {:ok, effects}
      else
        {:ok,
         [
           {:send, sender, {:error, :too_many_pending}}
         ]}
      end
    end

    # Handle collected responses
    on_message :response_collected, %{source: source, response: response}, _config, _env, sender do
      # This would be called by targets responding to gather_responses
      # In practice, this is a simplified version - real implementation would
      # match request IDs and aggregate properly

      IO.puts("📥 RelayEngine: Collected response from #{inspect(source)}: #{inspect(response)}")

      {:ok,
       [
         {:send, sender, :response_acknowledged}
       ]}
    end

    # Enhanced echo with metadata
    on_message :enhanced_echo, %{data: data}, _config, env, sender do
      metadata = %{
        relay_count: env.message_count,
        timestamp: DateTime.utc_now(),
        relay_engine: :RelayEngine,
        targets_configured: length(env.relay_targets)
      }

      new_count = env.message_count + 1
      new_env = %{env | message_count: new_count}

      IO.puts("🔊 RelayEngine: Enhanced echo with metadata for: #{inspect(data)}")

      {:ok,
       [
         {:update_environment, new_env},
         {:send, sender, {:echo_response, data, metadata}}
       ]}
    end

    # Handle echo responses (when we send enhanced_echo to other engines)
    on_message :echo_response,
               %{original_data: data, metadata: metadata},
               _config,
               _env,
               sender do
      IO.puts(
        "📻 RelayEngine: Received echo response from #{inspect(sender)}: #{inspect(data)} with #{inspect(metadata)}"
      )

      {:ok, []}
    end

    # Get relay statistics
    on_message :get_relay_stats, _msg_payload, _config, env, sender do
      stats = %{
        message_count: env.message_count,
        pending_count: map_size(env.pending_responses),
        targets: env.relay_targets
      }

      {:ok,
       [
         {:send, sender, {:relay_stats, stats}}
       ]}
    end

    # Handle stats responses
    on_message :relay_stats, stats, _config, _env, sender do
      IO.puts("📊 RelayEngine: Received stats from #{inspect(sender)}: #{inspect(stats)}")
      {:ok, []}
    end

    # Clear pending responses (maintenance operation)
    on_message :clear_pending, _msg_payload, _config, env, sender do
      new_env = %{env | pending_responses: %{}}
      IO.puts("🧹 RelayEngine: Cleared pending responses")

      {:ok,
       [
         {:update_environment, new_env},
         {:send, sender, :pending_cleared}
       ]}
    end

    # Standard ping-pong
    on_message :ping, _msg_payload, _config, env, sender do
      new_count = env.message_count + 1
      new_env = %{env | message_count: new_count}

      IO.puts("🏓 RelayEngine: Ping received, sending pong (msg #{new_count})")

      {:ok,
       [
         {:update_environment, new_env},
         {:send, sender, :pong}
       ]}
    end

    on_message :pong, _msg_payload, _config, _env, sender do
      IO.puts("🎉 RelayEngine: Pong received from #{inspect(sender)}")
      {:ok, []}
    end

    # Acknowledgment handler
    on_message :ack, _msg_payload, _config, _env, sender do
      IO.puts("✅ RelayEngine: Acknowledgment received from #{inspect(sender)}")
      {:ok, []}
    end
  end
end
