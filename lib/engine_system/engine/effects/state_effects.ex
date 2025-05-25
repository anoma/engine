defmodule EngineSystem.Engine.Effects.StateEffects do
  @moduledoc """
  I handle effects that modify engine state.

  I manage:
  - Environment updates
  - Mailbox filter changes
  - Engine termination
  """

  alias EngineSystem.Engine.{Instance, State}

  @doc """
  I execute an update_environment effect.

  ## Parameters

  - `new_environment` - The new environment state
  - `engine_state` - The current engine instance state

  ## Returns

  - `{:ok, updated_state}` if execution succeeded
  - `{:error, reason}` if execution failed
  """
  @spec execute_update_environment(State.Environment.t(), Instance.t()) ::
          {:ok, Instance.t()} | {:error, any()}
  def execute_update_environment(new_environment, engine_state) do
    updated_state = %{engine_state | environment: new_environment}
    {:ok, updated_state}
  end

  @doc """
  I execute an mfilter effect to update the mailbox filter.

  ## Parameters

  - `new_filter` - The new message filter function
  - `engine_state` - The current engine instance state

  ## Returns

  - `{:ok, updated_state}` if execution succeeded
  - `{:error, reason}` if execution failed
  """
  @spec execute_mfilter(function(), Instance.t()) :: {:ok, Instance.t()} | {:error, any()}
  def execute_mfilter(new_filter, engine_state) do
    # Update the engine's status with the new filter
    new_status = State.Status.ready(new_filter)
    updated_state = %{engine_state | status: new_status}

    # Also notify the mailbox of the filter change
    if engine_state.mailbox_pid do
      case GenStage.call(engine_state.mailbox_pid, {:update_filter, new_filter}) do
        :ok -> {:ok, updated_state}
        {:error, reason} -> {:error, {:mailbox_update_failed, reason}}
      end
    else
      {:ok, updated_state}
    end
  end

  @doc """
  I execute a terminate effect.

  ## Parameters

  - `engine_state` - The current engine instance state

  ## Returns

  - `{:ok, updated_state}` with terminated status
  """
  @spec execute_terminate(Instance.t()) :: {:ok, Instance.t()}
  def execute_terminate(engine_state) do
    # Update status to terminated
    new_status = State.Status.terminated()
    updated_state = %{engine_state | status: new_status}
    {:ok, updated_state}
  end

  @doc """
  I validate state-related effects.

  ## Parameters

  - `effect` - The effect to validate

  ## Returns

  - `:ok` if the effect is valid
  - `{:error, reason}` if the effect is invalid
  """
  @spec validate(any()) :: :ok | {:error, any()}
  def validate({:update_environment, %State.Environment{}}), do: :ok
  def validate({:update_environment, _}), do: {:error, :invalid_environment}
  def validate({:mfilter, filter}) when is_function(filter, 3), do: :ok
  def validate({:mfilter, _}), do: {:error, :invalid_filter_function}
  def validate(:terminate), do: :ok
  def validate(_), do: {:error, :not_state_effect}

  @doc """
  I check if an effect modifies the engine's environment.

  ## Parameters

  - `effect` - The effect to check

  ## Returns

  `true` if it modifies the environment, `false` otherwise.
  """
  @spec modifies_environment?(any()) :: boolean()
  def modifies_environment?({:update_environment, _}), do: true
  def modifies_environment?(_), do: false

  @doc """
  I check if an effect is a termination effect.

  ## Parameters

  - `effect` - The effect to check

  ## Returns

  `true` if it's a termination effect, `false` otherwise.
  """
  @spec termination?(any()) :: boolean()
  def termination?(:terminate), do: true
  def termination?(_), do: false
end
