defmodule EngineSystem.Engine.Effects.SystemEffects do
  @moduledoc """
  I handle effects that interact with the system.

  I manage:
  - Engine spawning
  - System-level operations
  - Noop effects
  """

  alias EngineSystem.Engine.Instance
  alias EngineSystem.System.Spawner

  @doc """
  I execute a noop (null operation) effect.

  ## Parameters

  - `engine_state` - The current engine instance state

  ## Returns

  - `{:ok, updated_state}` (unchanged state)
  """
  @spec execute_noop(Instance.t()) :: {:ok, Instance.t()}
  def execute_noop(engine_state) do
    {:ok, engine_state}
  end

  @doc """
  I execute a spawn effect to create a child engine.

  ## Parameters

  - `engine_module` - The engine module to spawn
  - `config` - The configuration for the new engine
  - `environment` - The environment for the new engine
  - `engine_state` - The current engine instance state

  ## Returns

  - `{:ok, updated_state}` if execution succeeded
  - `{:error, reason}` if execution failed
  """
  @spec execute_spawn(module(), any(), any(), Instance.t()) ::
          {:ok, Instance.t()} | {:error, any()}
  def execute_spawn(engine_module, config, environment, engine_state) do
    case Spawner.spawn_engine(engine_module, config, environment) do
      {:ok, _new_address} -> {:ok, engine_state}
      {:error, reason} -> {:error, {:spawn_failed, reason}}
    end
  end

  @doc """
  I validate system-related effects.

  ## Parameters

  - `effect` - The effect to validate

  ## Returns

  - `:ok` if the effect is valid
  - `{:error, reason}` if the effect is invalid
  """
  @spec validate(any()) :: :ok | {:error, any()}
  def validate(:noop), do: :ok

  def validate({:spawn, engine_module, _config, _environment}) when is_atom(engine_module) do
    :ok
  end

  def validate({:spawn, _, _, _}), do: {:error, :invalid_engine_module}
  def validate(_), do: {:error, :not_system_effect}
end
