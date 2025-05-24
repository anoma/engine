defmodule EngineSystem.Mailbox.DeliveryPolicy do
  @moduledoc """
  I define behavior contracts for custom delivery policies in mailbox engines.

  Custom delivery policies can implement sophisticated message ordering and filtering
  according to application-specific requirements.
  """

  alias EngineSystem.Types.MessageEnvelope

  @doc """
  Callback for inserting a message into the policy's storage structure.
  """
  @callback insert(storage :: any(), message :: MessageEnvelope.t(), opts :: any()) :: any()

  @doc """
  Callback for extracting messages from the policy's storage structure.
  """
  @callback extract(storage :: any(), count :: pos_integer(), opts :: any()) ::
              {messages :: list(MessageEnvelope.t()), new_storage :: any()}
end
