defmodule EngineSystem.Engine.Compilation.Types.MessageInterfaceSpec do
  @moduledoc """
  Defines the structure for the collection of messages an engine type can handle.
  """
  use TypedStruct

  alias EngineSystem.Engine.Compilation.Types.MessageSpec

  @default_messages []

  @typedoc """
  I specify the collection of messages an engine type can handle.

  ### Fields
  - `:messages` - A list of `MessageSpec.t()` defining individual messages.
    Enforced: true.

  An empty list of messages means the engine type can handle no messages.
  """
  typedstruct do
    field(
      :messages,
      list(MessageSpec.t()),
      enforce: true,
      default: @default_messages
    )
  end
end
