defmodule EngineSystem.Types.EngineMode do
  @moduledoc """
  I define the possible operational modes of an engine, differentiating its role.

  As per the formal model (Definition 3.8), an engine can operate in one of two modes:
  - `:process`: Indicates a processing engine that executes business logic.
  - `:mail`: Indicates a mailbox engine responsible for message buffering and delivery for a processing engine.
  """

  @typedoc """
  Represents the operational mode of an engine.

  Can be one of:
  - `:process` - The engine is a processing engine.
  - `:mail` - The engine is a mailbox engine.
  """
  @type t :: :process | :mail
end
