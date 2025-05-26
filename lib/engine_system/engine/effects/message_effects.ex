defmodule EngineSystem.Engine.Effects.MessageEffects do
  @moduledoc """
  I handle effects related to message sending and communication.

  I manage:
  - Message sending between engines
  - Message validation
  """

  alias EngineSystem.Engine.{Instance, State}
  alias EngineSystem.Mailbox.Message
  alias EngineSystem.System.Services

  @doc """
  I execute a send effect for message dispatch.

  ## Parameters

  - `target_address` - The address to send the message to
  - `message_payload` - The message payload to send
  - `engine_state` - The current engine instance state

  ## Returns

  - `{:ok, updated_state}` if execution succeeded
  - `{:error, reason}` if execution failed
  """
  @spec execute_send(State.address(), any(), Instance.t()) ::
          {:ok, Instance.t()} | {:error, any()}
  def execute_send(target_address, message_payload, engine_state) do
    message = Message.new(engine_state.address, target_address, message_payload)

    case Services.send_message(target_address, message) do
      :ok -> {:ok, engine_state}
      {:error, reason} -> {:error, {:send_failed, reason}}
    end
  end

  @doc """
  I validate message-related effects.

  ## Parameters

  - `effect` - The effect to validate

  ## Returns

  - `:ok` if the effect is valid
  - `{:error, reason}` if the effect is invalid
  """
  @spec validate(any()) :: :ok | {:error, :not_message_effect | {:invalid_address, any()}}
  def validate({:send, target_address, _message_payload}) do
    case target_address do
      {node_id, engine_id} when is_integer(node_id) and is_integer(engine_id) -> :ok
      _ -> {:error, {:invalid_address, target_address}}
    end
  end

  def validate(_), do: {:error, :not_message_effect}
end
