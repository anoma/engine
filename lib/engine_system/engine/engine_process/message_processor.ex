defmodule EngineSystem.Engine.EngineProcess.MessageProcessor do
  @moduledoc """
  I handle message processing for engine processes.

  I'm responsible for:
  - Processing incoming messages
  - Finding matching guarded actions
  - Orchestrating guard evaluation and action execution
  """

  require Logger

  alias EngineSystem.Engine.Compilation.Types.GuardedActionSpec
  alias EngineSystem.Engine.EngineProcess.{EffectProcessor, Evaluator}
  alias EngineSystem.Types.{MessageEnvelope, OperationResult}

  @type engine_address :: {:engine, node(), pos_integer()} | {:sender, pid()}
  @type environment :: any()
  @type config :: map()

  @doc """
  I process a message envelope and return the updated state and result.
  """
  @spec process_message(MessageEnvelope.t(), any()) :: {any(), OperationResult.t()}
  def process_message(envelope, state) do
    # Extract the message tag and payload from the original_payload
    original_payload = envelope.original_payload
    message_tag = elem(original_payload, 0)

    # Extract the payload based on the tuple size
    payload = extract_payload_from_tuple(original_payload)

    # Find matching guarded actions
    matching_actions = find_matching_guarded_actions(message_tag, payload, state)

    case matching_actions do
      [] ->
        # No matching actions, return error
        new_state = remove_message_from_mailbox(state, envelope.message_id)
        {new_state, OperationResult.error(:no_matching_action)}

      [action | _] ->
        # Execute the first matching action
        result =
          Evaluator.execute_action(
            action,
            payload,
            envelope.sender_address,
            state.config,
            state.environment,
            state.engine_spec.type_name
          )

        # Process the result to extract the new environment and effects
        {new_environment, effect} =
          EffectProcessor.process_action_result(result, state.environment)

        # Update the environment and remove message from mailbox
        updated_state = %{
          state
          | environment: new_environment,
            mailbox: remove_message_from_mailbox(state, envelope.message_id).mailbox,
            pending_effects: [effect]
        }

        # Process the effect
        final_state = EffectProcessor.execute_effect(effect, updated_state)

        {final_state, OperationResult.ok()}
    end
  end

  @doc """
  I find guarded actions that match a message tag and payload.
  """
  @spec find_matching_guarded_actions(atom(), any(), any()) :: [GuardedActionSpec.t()]
  def find_matching_guarded_actions(message_tag, payload, state) do
    # Filter guarded actions that match the message tag
    matching_actions =
      Enum.filter(state.engine_spec.behaviour_spec.guarded_actions, fn action ->
        action.message_tag == message_tag
      end)

    # Evaluate the guards for each matching action
    Enum.filter(matching_actions, fn action ->
      Evaluator.evaluate_guard(action, payload, state.config, state.environment)
    end)
  end

  # --- Private Functions --- #

  @spec extract_payload_from_tuple(tuple()) :: any()
  defp extract_payload_from_tuple(original_payload) do
    case tuple_size(original_payload) do
      1 ->
        nil

      2 ->
        elem(original_payload, 1)

      _ ->
        # For tuples with more than 2 elements, we need to handle them differently
        # For example, {:put, :key, "value"} should have :key and "value" as payload
        payload_size = tuple_size(original_payload) - 1
        payload_elements = for i <- 1..payload_size, do: elem(original_payload, i)
        List.to_tuple(payload_elements)
    end
  end

  @spec remove_message_from_mailbox(any(), String.t()) :: any()
  defp remove_message_from_mailbox(state, message_id) do
    %{
      state
      | mailbox: Enum.reject(state.mailbox, fn m -> m.message_id == message_id end)
    }
  end
end
