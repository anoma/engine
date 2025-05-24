defmodule EngineSystem.Types.MessageEnvelope do
  @moduledoc """
  I represent a message being processed by an engine instance.

  I encapsulate the original message payload along with metadata such as a unique
  message ID, the sender's address, and a timestamp.

  ### Public API

  I have the following public functionality (primarily the struct fields):

  - `:message_id`
  - `:original_payload`
  - `:sender_address`
  - `:timestamp`
  """
  use TypedStruct

  @type message_id :: String.t()
  @type engine_address :: any()
  @type timestamp :: integer()

  typedstruct do
    @typedoc """
    I define the structure for a message envelope.

    ### Fields

    - `:message_id` - A unique identifier for this message instance. Enforced: true.
    - `:original_payload` - The original message content as sent by the originator. Enforced: true.
    - `:sender_address` - The address of the engine or entity that sent this message. Enforced: true.
    - `:timestamp` - The time at which the message was created or received (milliseconds since epoch). Enforced: true.
    """
    field(:message_id, message_id(), enforce: true)
    field(:original_payload, any(), enforce: true)
    field(:sender_address, engine_address(), enforce: true)
    field(:timestamp, timestamp(), enforce: true)
  end
end
