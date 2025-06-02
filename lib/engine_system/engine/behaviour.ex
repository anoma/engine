defmodule EngineSystem.Engine.Behaviour do
  @moduledoc """
  I contain functions for evaluating an engine's behaviour against an incoming message.

  I implement guard matching and action selection strategies, taking an Engine.Spec,
  current Engine.State, and a System.Message as input, and returning the list of
  Engine.Effects to be executed.

  This implements the logic of behaviourtype and b-rules (guard evaluation) from
  the formal model.

  ## Public API

  ### Behaviour Evaluation
  - `evaluate/4` - Evaluate an engine's behaviour against an incoming message
  - `find_matching_rule/4` - Find the first behaviour rule that matches the given message
  - `execute_rule/4` - Execute a behaviour rule to produce effects
  """

  alias EngineSystem.Engine.{Effect, Spec, State}
  alias EngineSystem.System.Message

  @type evaluation_result :: {:ok, [Effect.t()]} | {:error, any()}

  @doc """
  I evaluate the behaviour of an engine for a given message.

  This is the main entry point for behaviour evaluation. I find the appropriate
  behaviour rule for the message and execute it to produce effects.

  ## Parameters

  - `spec` - The engine specification containing behaviour rules
  - `message` - The message to process
  - `configuration` - The engine's configuration
  - `environment` - The engine's environment

  ## Returns

  - `{:ok, effects}` if evaluation succeeded
  - `{:error, reason}` if evaluation failed
  """
  @spec evaluate(Spec.t(), Message.t(), State.Configuration.t(), State.Environment.t()) ::
          evaluation_result()
  def evaluate(spec, message, configuration, environment) do
    # Here is where the guard-action evaluation strategy is implemented.
    case find_matching_rule(spec.behaviour_rules, message, configuration, environment) do
      {:ok, rule} ->
        execute_rule(rule, message, configuration, environment)

      :no_match ->
        # No matching rule found, return noop effect
        {:ok, [Effect.noop()]}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  I find the first behaviour rule that matches the given message.

  This implements the guard selection strategy. For simplicity, I use a
  first-match strategy where I execute the first rule whose guard is satisfied.

  ## Parameters

  - `rules` - The list of behaviour rules from the engine spec
  - `message` - The message to match against
  - `configuration` - The engine's configuration
  - `environment` - The engine's environment

  ## Returns

  - `{:ok, rule}` if a matching rule is found
  - `:no_match` if no rule matches
  - `{:error, reason}` if evaluation fails
  """
  @spec find_matching_rule(
          [Spec.behaviour_rule()],
          Message.t(),
          State.Configuration.t(),
          State.Environment.t()
        ) ::
          {:ok, Spec.behaviour_rule()} | :no_match | {:error, any()}
  def find_matching_rule(rules, %Message{payload: {tag, _payload}}, _configuration, _environment) do
    find_rule_by_tag(rules, tag)
  end

  def find_matching_rule(rules, %Message{payload: tag}, _configuration, _environment)
      when is_atom(tag) do
    find_rule_by_tag(rules, tag)
  end

  def find_matching_rule(rules, {tag, _payload}, _configuration, _environment) do
    find_rule_by_tag(rules, tag)
  end

  def find_matching_rule(_rules, message, _configuration, _environment) do
    {:error, {:invalid_message_format, message}}
  end

  defp find_rule_by_tag(rules, tag) do
    case Enum.find(rules, fn {rule_tag, _action} -> rule_tag == tag end) do
      nil -> :no_match
      rule -> {:ok, rule}
    end
  end

  @doc """
  I execute a behaviour rule to produce effects.

  ## Parameters

  - `rule` - The behaviour rule to execute
  - `message` - The message being processed
  - `configuration` - The engine's configuration
  - `environment` - The engine's environment

  ## Returns

  - `{:ok, effects}` if execution succeeded
  - `{:error, reason}` if execution failed
  """
  @spec execute_rule(
          Spec.behaviour_rule(),
          Message.t(),
          State.Configuration.t(),
          State.Environment.t()
        ) ::
          evaluation_result()
  def execute_rule(
        {_tag, action_ast},
        %Message{payload: {tag, payload}, sender: sender},
        configuration,
        environment
      ) do
    execute_action(action_ast, tag, payload, sender, configuration, environment)
  end

  def execute_rule(
        {_tag, action_ast},
        %Message{payload: tag, sender: sender},
        configuration,
        environment
      )
      when is_atom(tag) do
    execute_action(action_ast, tag, nil, sender, configuration, environment)
  end

  def execute_rule({_tag, action_ast}, {tag, payload}, configuration, environment) do
    # Handle simple tuple messages (assume no sender for now)
    execute_action(action_ast, tag, payload, nil, configuration, environment)
  end

  def execute_rule(_rule, message, _configuration, _environment) do
    {:error, {:unsupported_message_format, message}}
  end

  @spec execute_action(
          any(),
          atom(),
          any(),
          any(),
          State.Configuration.t(),
          State.Environment.t()
        ) ::
          {:ok, [Effect.t()]}
  def execute_action(
        {:function_handler, module, handler_name},
        tag,
        payload,
        sender,
        configuration,
        environment
      ) do
    # Execute function-based handler with compile-time validation
    # Create proper payload structure based on tag
    msg_payload =
      case payload do
        # Simple atom message
        nil -> tag
        # Structured payload
        _ -> payload
      end

    # Extract the actual raw environment data
    # Handle case where local_state might be nested State.Environment structs
    raw_env_data =
      case environment.local_state do
        %State.Environment{local_state: actual_data} ->
          # Double-nested case: extract the actual raw data
          actual_data

        raw_data ->
          # Normal case: local_state is already raw data
          raw_data
      end

    apply(module, handler_name, [
      msg_payload,
      configuration.engine_specific,
      # Pass the raw data, not the nested struct
      raw_env_data,
      sender
    ])
  rescue
    error ->
      {:error, {:function_handler_error, error}}
  end

  def execute_action(_action_ast, :get, payload, sender, _configuration, environment) do
    # Example: GET operation might send a result back
    effects =
      if sender do
        [Effect.send(sender, {:result, get_value_from_environment(payload, environment)})]
      else
        [Effect.noop()]
      end

    {:ok, effects}
  end

  def execute_action(_action_ast, :put, payload, sender, _configuration, environment) do
    # Example: PUT operation might update environment and send ack
    effects = [Effect.update_environment(put_value_in_environment(payload, environment))]

    final_effects =
      if sender do
        effects ++ [Effect.send(sender, {:ack})]
      else
        effects
      end

    {:ok, final_effects}
  end

  def execute_action(_action_ast, :delete, payload, sender, _configuration, environment) do
    # Example: DELETE operation
    effects = [Effect.update_environment(delete_value_from_environment(payload, environment))]

    final_effects =
      if sender do
        effects ++ [Effect.send(sender, {:ack})]
      else
        effects
      end

    {:ok, final_effects}
  end

  def execute_action(_action_ast, _tag, _payload, _sender, _configuration, _environment) do
    # Default: just noop
    {:ok, [Effect.noop()]}
  end

  # Helper functions for common operations
  # These would be more sophisticated in a real implementation

  @spec get_value_from_environment(any(), State.Environment.t()) :: any()
  defp get_value_from_environment(key, environment) do
    case environment.local_state do
      %{store: store} when is_map(store) ->
        Map.get(store, key, :not_found)

      _ ->
        :not_found
    end
  end

  @spec put_value_in_environment({any(), any()}, State.Environment.t()) :: State.Environment.t()
  defp put_value_in_environment({key, value}, environment) do
    case environment.local_state do
      %{store: store} when is_map(store) ->
        new_store = Map.put(store, key, value)
        new_local_state = %{environment.local_state | store: new_store}
        %{environment | local_state: new_local_state}

      _ ->
        # Initialize with a new store if it doesn't exist
        new_local_state = %{store: %{key => value}}
        %{environment | local_state: new_local_state}
    end
  end

  @spec delete_value_from_environment(any(), State.Environment.t()) :: State.Environment.t()
  defp delete_value_from_environment(key, environment) do
    case environment.local_state do
      %{store: store} when is_map(store) ->
        new_store = Map.delete(store, key)
        new_local_state = %{environment.local_state | store: new_store}
        %{environment | local_state: new_local_state}

      _ ->
        environment
    end
  end

  @doc """
  I validate that a behaviour rule is well-formed.

  ## Parameters

  - `rule` - The behaviour rule to validate

  ## Returns

  - `:ok` if the rule is valid
  - `{:error, reason}` if the rule is invalid
  """
  @spec validate_rule(Spec.behaviour_rule()) :: :ok | {:error, any()}
  def validate_rule({tag, _action}) when is_atom(tag) do
    :ok
  end

  def validate_rule(rule) do
    {:error, {:invalid_rule_format, rule}}
  end

  @doc """
  I validate that all behaviour rules in a spec are well-formed.

  ## Parameters

  - `spec` - The engine specification

  ## Returns

  - `:ok` if all rules are valid
  - `{:error, reason}` if any rule is invalid
  """
  @spec validate_behaviour(Spec.t()) :: :ok | {:error, any()}
  def validate_behaviour(%Spec{behaviour_rules: rules}) do
    find_invalid_rule(rules)
  end

  defp find_invalid_rule(rules) do
    case Enum.find(rules, fn rule -> validate_rule(rule) != :ok end) do
      nil -> :ok
      invalid_rule -> {:error, {:invalid_behaviour_rule, invalid_rule}}
    end
  end
end
