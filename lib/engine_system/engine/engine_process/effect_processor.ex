defmodule EngineSystem.Engine.EngineProcess.EffectProcessor do
  @moduledoc """
  I handle effect processing for engine processes according to the formal Engine Model specification.

  I'm responsible for:
  - Processing action results into effects as defined in the formal model
  - Executing individual effects: noop, send, update, spawn, mfilter, terminate, chain
  - Managing effect processing workflows per the operational semantics
  """

  require Logger

  alias EngineSystem.Types.OperationResult

  @type engine_address :: {:engine, node(), pos_integer()} | {:sender, pid()}
  @type engine_type_name :: atom() | String.t()
  @type config :: map()
  @type environment :: any()

  # Effect types matching the formal model (Definition 6.1)
  @type effect ::
          :noop
          | {:send, engine_address(), any()}
          | {:update, environment()}
          | {:spawn, {engine_type_name(), config(), environment()}}
          | {:mfilter, (any() -> boolean())}
          | :terminate
          | {:chain, effect(), effect()}

  @type action_result :: effect() | list(effect())

  @doc """
  I process an action result according to the formal model.

  Actions can return:
  - A single effect
  - A list of effects (which will be chained)
  - nil (treated as noop)
  """
  @spec process_action_result(action_result(), environment()) :: {environment(), effect()}
  def process_action_result(result, current_environment) do
    case result do
      nil ->
        {current_environment, :noop}

      [] ->
        {current_environment, :noop}

      effect when is_atom(effect) and effect == :noop ->
        {current_environment, :noop}

      effect when is_atom(effect) and effect == :terminate ->
        {current_environment, :terminate}

      {:send, recipient, message} ->
        {current_environment, {:send, recipient, message}}

      {:update, new_env} ->
        {new_env, :noop}

      {:spawn, {engine_type, config, env}} ->
        {current_environment, {:spawn, {engine_type, config, env}}}

      {:mfilter, filter_fun} ->
        {current_environment, {:mfilter, filter_fun}}

      {:chain, effect1, effect2} ->
        {current_environment, {:chain, effect1, effect2}}

      effects when is_list(effects) ->
        # Convert list of effects to chained effects
        case effects do
          [] ->
            {current_environment, :noop}

          [single_effect] ->
            process_action_result(single_effect, current_environment)

          [first | rest] ->
            {env_after_first, first_effect} = process_action_result(first, current_environment)
            {final_env, rest_effect} = process_action_result(rest, env_after_first)
            {final_env, {:chain, first_effect, rest_effect}}
        end

      _ ->
        Logger.warning("Unknown action result format: #{inspect(result)}")
        {current_environment, :noop}
    end
  end

  @doc """
  I execute a single effect according to the formal operational semantics.
  """
  @spec execute_effect(effect(), any()) :: any()
  def execute_effect(effect, state) do
    case effect do
      :noop ->
        # Null operation - no state change
        state

      {:send, recipient, message} ->
        # Execute send effect (e-Send rule)
        try do
          EngineSystem.System.Services.send_message(recipient, message)
        rescue
          error ->
            Logger.error("Failed to send message: #{inspect(error)}")
        end

        state

      {:update, new_environment} ->
        # Execute update effect (e-Update rule)
        %{state | environment: new_environment}

      {:spawn, {engine_type, config, env}} ->
        # Execute spawn effect (e-Spawn rule)
        # According to the formal rule, we should call the system's spawn operation
        # with all required parameters including the environment
        case EngineSystem.System.Services.create_engine_instance({engine_type, "1.0"}, config) do
          %OperationResult{status: :ok, value: address} ->
            Logger.info(
              "Successfully spawned engine of type #{inspect(engine_type)} at #{inspect(address)} with env #{inspect(env)}"
            )

          # NOTE: The formal rule requires proper handling of environment parameter.
          # This requires extending the system services to accept the environment parameter.
          # For now, the spawned engine will use default environment initialization.

          %OperationResult{status: :error, reason: reason} ->
            Logger.error("Failed to spawn engine: #{inspect(reason)}")
        end

        state

      {:mfilter, filter_fun} ->
        # Execute mfilter effect (e-MFilter rule)
        %{state | status: {:ready, filter_fun}}

      :terminate ->
        # Execute terminate effect (e-Terminate rule)
        # According to the formal rule, this should delegate to the system's clean operation
        # For now, we simulate this by setting terminated status and scheduling cleanup
        Logger.info("Engine terminating - delegating to system clean operation")
        Process.send_after(self(), :do_terminate, 0)
        %{state | status: :terminated}

      {:chain, effect1, effect2} ->
        # Execute chain effect (e-Chain rule) - apply effects sequentially
        state_after_effect1 = execute_effect(effect1, state)
        execute_effect(effect2, state_after_effect1)

      _ ->
        Logger.warning("Unknown effect type: #{inspect(effect)}")
        state
    end
  end

  @doc """
  I execute multiple effects by chaining them together.
  This is a convenience function for backward compatibility.
  """
  @spec execute_effects([effect()], any()) :: any()
  def execute_effects([], state), do: state
  def execute_effects([single_effect], state), do: execute_effect(single_effect, state)

  def execute_effects(effects, state) when is_list(effects) do
    # Convert to chained effect and execute
    chained_effect = effects_to_chain(effects)
    execute_effect(chained_effect, state)
  end

  # --- Private Functions --- #

  @spec effects_to_chain([effect()]) :: effect()
  defp effects_to_chain([]), do: :noop
  defp effects_to_chain([single]), do: single
  defp effects_to_chain([first | rest]), do: {:chain, first, effects_to_chain(rest)}
end
