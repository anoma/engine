defmodule EngineSystem.Mailbox.DefaultMailboxEngine do
  @moduledoc """
  I am the default mailbox engine implementation using the DSL.

  I provide basic FIFO message queuing functionality when no custom mailbox
  is specified for a processing engine. I implement the mailbox-as-actors
  pattern with:

  - Message validation against processing engine interface
  - FIFO message queuing
  - Message filtering based on processing engine status
  - GenStage producer functionality for backpressure control

  This module is defined using the engine DSL and compiles to a GenStage producer.
  """

  use EngineSystem

  # Import utility functions for message validation and queue operations
  import EngineSystem.Engine, only: [validate_message_for_pe: 2, extract_messages: 3]

  defengine DefaultMailbox do
    version("1.0.0")
    mode(:mailbox)

    # Configuration for default mailbox behavior
    config do
      %{
        delivery_policy: :fifo,
        max_buffer_size: 1000,
        batch_size: 10,
        producer_type: :demand_driven
      }
    end

    # Environment holds the mailbox's internal state
    env do
      %{
        # Message queue - simple FIFO queue
        message_queue: :queue.new(),
        # Current demand from processing engine
        current_demand: 0,
        # Processing engine filter function (will be set at runtime)
        pe_filter: nil,
        # Processing engine status tracking
        pe_is_down: false,
        # Statistics
        total_received: 0,
        total_delivered: 0,
        # Processing engine info for validation
        pe_spec: nil,
        pe_address: nil
      }
    end

    # Internal message interface for mailbox operations
    interface do
      # External message to enqueue for processing engine
      message(:enqueue_message, [:message])

      # Demand request from processing engine (internal GenStage)
      message(:request_batch, [:demand])

      # Filter update from processing engine
      message(:update_filter, [:filter])

      # Internal dispatch trigger
      message(:check_dispatch)

      # Processing engine status notifications
      message(:pe_down)
      message(:pe_ready)
    end

    behaviour do
      # Handle message enqueueing (m-Enqueue rule)
      # Using function-based syntax for compile-time validation
      on_message :enqueue_message, %{message: message}, _config, env, _sender do
        IO.puts("📮 Mailbox #{inspect(env.pe_address)}: Received enqueue_message with payload: #{inspect(message.payload)}")
        IO.puts("📮 Mailbox #{inspect(env.pe_address)}: PE spec available: #{not is_nil(env.pe_spec)}")

        # Validate message against processing engine interface
        # Extract payload for validation since validate_message_for_pe expects payload format
        validation_message = %{payload: message.payload}

        case validate_message_for_pe(validation_message, env.pe_spec) do
          :ok ->
            IO.puts("📮 Mailbox #{inspect(env.pe_address)}: Message validation passed, adding to queue")
            # Add to queue
            new_queue = :queue.in(message, env.message_queue)
            new_env = %{env | message_queue: new_queue, total_received: env.total_received + 1}

            effects = [{:update_environment, new_env}]

            # If there's demand, try to dispatch immediately
            if env.current_demand > 0 do
              IO.puts("📮 Mailbox #{inspect(env.pe_address)}: Demand available (#{env.current_demand}), triggering dispatch")
              {:ok, effects ++ [{:send, :self, :check_dispatch}]}
            else
              IO.puts("📮 Mailbox #{inspect(env.pe_address)}: No demand, message queued")
              {:ok, effects}
            end

          {:error, reason} ->
            # Invalid message - log and ignore
            IO.puts("⚠️  Mailbox #{inspect(env.pe_address)}: Invalid message rejected: #{inspect(reason)}")
            {:ok, []}
        end
      end

      # Handle demand requests (m-Dequeue rule)
      on_message :request_batch, %{demand: demand}, _config, env, _sender do
        new_demand = env.current_demand + demand
        new_env = %{env | current_demand: new_demand}

        # Extract messages from queue up to demand
        {messages, remaining_queue} = extract_messages(env.message_queue, demand, env.pe_filter)

        final_env = %{
          new_env
          | message_queue: remaining_queue,
            current_demand: new_demand - length(messages),
            total_delivered: env.total_delivered + length(messages)
        }

        effects = [{:update_environment, final_env}]

        # Deliver messages if any
        if length(messages) > 0 do
          {:ok, effects ++ [{:deliver_batch, messages}]}
        else
          {:ok, effects}
        end
      end

      # Handle check_dispatch - process queued messages when there's demand
      on_message :check_dispatch, _msg, _config, env, _sender do
        IO.puts(
          "📮 Mailbox #{inspect(env.pe_address)}: Processing check_dispatch - current_demand: #{env.current_demand}, queue_size: #{:queue.len(env.message_queue)}"
        )

        if env.current_demand > 0 and :queue.len(env.message_queue) > 0 do
          # Extract messages from queue up to demand
          {messages, remaining_queue} =
            extract_messages(env.message_queue, env.current_demand, env.pe_filter)

          final_env = %{
            env
            | message_queue: remaining_queue,
              current_demand: env.current_demand - length(messages),
              total_delivered: env.total_delivered + length(messages)
          }

          effects = [{:update_environment, final_env}]

          # Deliver messages if any
          if length(messages) > 0 do
            IO.puts("📮 Mailbox #{inspect(env.pe_address)}: Dispatching #{length(messages)} messages")
            {:ok, effects ++ [{:deliver_batch, messages}]}
          else
            IO.puts("📮 Mailbox #{inspect(env.pe_address)}: No messages to dispatch after filtering")
            {:ok, effects}
          end
        else
          IO.puts(
            "📮 Mailbox #{inspect(env.pe_address)}: No dispatch needed - demand: #{env.current_demand}, queue: #{:queue.len(env.message_queue)}"
          )

          {:ok, []}
        end
      end

      # Handle filter updates
      on_message :update_filter, %{filter: filter}, _config, env, _sender do
        new_env = %{env | pe_filter: filter}

        effects = [{:update_environment, new_env}]

        # Check if any queued messages can now be dispatched
        if env.current_demand > 0 and :queue.len(env.message_queue) > 0 do
          {:ok, effects ++ [{:send, :self, :check_dispatch}]}
        else
          {:ok, effects}
        end
      end

      # Handle processing engine down
      on_message :pe_down, _msg, _config, env, _sender do
        new_env = %{env | pe_is_down: true, current_demand: 0}
        {:ok, [{:update_environment, new_env}]}
      end

      # Handle processing engine ready
      on_message :pe_ready, _msg, _config, env, _sender do
        new_env = %{env | pe_is_down: false}
        {:ok, [{:update_environment, new_env}]}
      end
    end
  end
end
