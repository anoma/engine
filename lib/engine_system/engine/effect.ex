defmodule EngineSystem.Engine.Effect do
  @moduledoc """
  I define structs and logic for executing effects.

  I implement the effecttype and e-rules (effect execution) from the formal model.
  Effects represent primitive operations that an engine requests the system to execute,
  such as noop, send, update, spawn, mfilter, terminate, and chain.
  """

  alias EngineSystem.Engine.{Instance, State}
  alias EngineSystem.Engine.Effects.{MessageEffects, StateEffects, SystemEffects}

  @type t ::
          :noop
          | {:send, State.address(), any()}
          | {:update_environment, State.Environment.t()}
          | {:spawn, module(), any(), any()}
          | {:mfilter, function()}
          | :terminate
          | {:chain, [t()]}

  @doc """
  I create a noop (null operation) effect.

  ## Returns

  A noop effect.
  """
  @spec noop() :: t()
  def noop, do: :noop

  @doc """
  I create a send effect for message dispatch.

  ## Parameters

  - `target_address` - The address to send the message to
  - `message_payload` - The message payload to send

  ## Returns

  A send effect.
  """
  @spec send(State.address(), any()) :: t()
  def send(target_address, message_payload) do
    {:send, target_address, message_payload}
  end

  @doc """
  I create an update effect to change the engine's environment.

  ## Parameters

  - `new_environment` - The new environment state

  ## Returns

  An update effect.
  """
  @spec update_environment(State.Environment.t()) :: t()
  def update_environment(new_environment) do
    {:update_environment, new_environment}
  end

  @doc """
  I create a spawn effect to create a child engine.

  ## Parameters

  - `engine_module` - The engine module to spawn
  - `config` - The configuration for the new engine
  - `environment` - The environment for the new engine

  ## Returns

  A spawn effect.
  """
  @spec spawn(module(), any(), any()) :: t()
  def spawn(engine_module, config, environment) do
    {:spawn, engine_module, config, environment}
  end

  @doc """
  I create an mfilter effect to replace the mailbox filter.

  ## Parameters

  - `new_filter` - The new message filter function

  ## Returns

  An mfilter effect.
  """
  @spec mfilter(function()) :: t()
  def mfilter(new_filter) do
    {:mfilter, new_filter}
  end

  @doc """
  I create a terminate effect for engine shutdown.

  ## Returns

  A terminate effect.
  """
  @spec terminate() :: t()
  def terminate, do: :terminate

  @doc """
  I create a chain effect for effect sequencing.

  ## Parameters

  - `effects` - List of effects to execute in sequence

  ## Returns

  A chain effect.
  """
  @spec chain([t()]) :: t()
  def chain(effects) do
    {:chain, effects}
  end

  @doc """
  I execute an effect within the context of an engine instance.

  ## Parameters

  - `effect` - The effect to execute
  - `engine_state` - The current engine instance state

  ## Returns

  - `{:ok, updated_state}` if execution succeeded
  - `{:error, reason}` if execution failed
  """
  @spec execute(t(), Instance.t()) :: {:ok, Instance.t()} | {:error, any()}
  def execute(:noop, engine_state) do
    SystemEffects.execute_noop(engine_state)
  end

  def execute({:send, target_address, message_payload}, engine_state) do
    MessageEffects.execute_send(target_address, message_payload, engine_state)
  end

  def execute({:update_environment, new_environment}, engine_state) do
    StateEffects.execute_update_environment(new_environment, engine_state)
  end

  def execute({:spawn, engine_module, config, environment}, engine_state) do
    SystemEffects.execute_spawn(engine_module, config, environment, engine_state)
  end

  def execute({:mfilter, new_filter}, engine_state) do
    StateEffects.execute_mfilter(new_filter, engine_state)
  end

  def execute(:terminate, engine_state) do
    StateEffects.execute_terminate(engine_state)
  end

  def execute({:chain, effects}, engine_state) do
    # Execute effects sequentially
    Enum.reduce_while(effects, {:ok, engine_state}, fn effect, {:ok, current_state} ->
      case execute(effect, current_state) do
        {:ok, updated_state} -> {:cont, {:ok, updated_state}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  def execute(unknown_effect, _engine_state) do
    {:error, {:unknown_effect, unknown_effect}}
  end

  @doc """
  I validate that an effect is well-formed.

  ## Parameters

  - `effect` - The effect to validate

  ## Returns

  - `:ok` if the effect is valid
  - `{:error, reason}` if the effect is invalid
  """
  @spec validate(t()) :: :ok | {:error, any()}
  def validate(effect) do
    cond do
      match?(:noop, effect) ->
        :ok

      match?({:chain, _}, effect) ->
        validate_chain_effect(effect)

      true ->
        # Try each specialized validator in sequence
        with {:error, :not_system_effect} <- SystemEffects.validate(effect),
             {:error, :not_message_effect} <- MessageEffects.validate(effect),
             {:error, :not_state_effect} <- StateEffects.validate(effect) do
          {:error, {:unknown_effect_type, effect}}
        end
    end
  end

  defp validate_chain_effect({:chain, effects}) when is_list(effects) do
    case Enum.find(effects, fn effect -> validate(effect) != :ok end) do
      nil -> :ok
      invalid_effect -> {:error, {:invalid_chained_effect, invalid_effect}}
    end
  end

  defp validate_chain_effect({:chain, _}), do: {:error, :invalid_chain_effects}
  defp validate_chain_effect(effect), do: {:error, {:unknown_effect_type, effect}}
end
