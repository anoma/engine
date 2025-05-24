defmodule EngineSystem.Types.EngineStatus do
  @moduledoc """
  I define the possible operational statuses of an engine.
  """

  alias EngineSystem.Types.MessageEnvelope

  @typedoc """
  Represents the operational status of an engine.

  - `{:ready, filter_fun}`: The engine is ready to process messages that satisfy the filter.
    `filter_fun` is a function `(MessageEnvelope.t() -> boolean())`.
  - `{:busy, message_envelope}`: The engine is currently processing the given message.
  - `:terminated`: The engine has terminated and will not process further messages.
  """
  @type t(message_envelope) ::
          {:ready, (message_envelope -> boolean())} | {:busy, message_envelope} | :terminated

  # Default filter function type, assuming MessageEnvelope.t() as the argument type
  @type filter_fun :: (MessageEnvelope.t() -> boolean())

  # Example of a default filter that accepts all messages
  def default_filter(_envelope \\ nil) do
    true
  end
end
