defmodule EngineSystem.Engine.Compilation.Types.BehaviourSpec do
  @moduledoc """
  Defines the structure for an engine type's behaviour as a list of guarded actions.
  """
  use TypedStruct

  alias EngineSystem.Engine.Compilation.Types.GuardedActionSpec

  @default_guarded_actions []

  @typedoc """
  I specify the behaviour of an engine type as a list of guarded actions.

  ### Fields
  - `:guarded_actions` - A list of `GuardedActionSpec.t()`. Enforced: true.
  """
  typedstruct do
    field(
      :guarded_actions,
      list(GuardedActionSpec.t()),
      enforce: true,
      default: @default_guarded_actions
    )
  end
end
