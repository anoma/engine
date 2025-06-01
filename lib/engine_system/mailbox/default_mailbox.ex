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

  defengine DefaultMailbox do
    version "1.0.0"
    mode :mailbox

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

      # Processing engine status notifications
      message(:pe_down)
      message(:pe_ready)
    end

    behaviour do
      # Handle message enqueueing (m-Enqueue rule)
      # Using function-based syntax for compile-time validation
      on_message :enqueue_message, %{message: message}, _config, env, _sender do
        # Validate message against processing engine interface
        case validate_message_for_pe(message, env.pe_spec) do
          :ok ->
            # Add to queue
            new_queue = :queue.in(message, env.message_queue)
            new_env = %{env | message_queue: new_queue, total_received: env.total_received + 1}

            effects = [{:update_environment, new_env}]

            # If there's demand, try to dispatch immediately
            if env.current_demand > 0 do
              {:ok, effects ++ [{:send, :self, {:check_dispatch}}]}
            else
              {:ok, effects}
            end

          {:error, _reason} ->
            # Invalid message - just ignore (could log if needed)
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

      # Handle filter updates
      on_message :update_filter, %{filter: filter}, _config, env, _sender do
        new_env = %{env | pe_filter: filter}

        effects = [{:update_environment, new_env}]

        # Check if any queued messages can now be dispatched
        if env.current_demand > 0 and :queue.len(env.message_queue) > 0 do
          {:ok, effects ++ [{:send, :self, {:check_dispatch}}]}
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
