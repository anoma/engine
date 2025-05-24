defmodule EngineSystem.Engine.Compilation.Types.GuardedActionSpec do
  @moduledoc """
  Defines the structure for a single guarded action within an engine's behaviour.
  """
  use TypedStruct

  @typedoc """
  I specify a single guarded action within an engine's behaviour.

  ### Fields
  - `:message_tag` - The message tag this action handles. Enforced: true.
  - `:payload_bindings_ast` - Quoted AST for binding variables from the message payload. Enforced: true.
  - `:context_bindings_ast` - Quoted AST for binding context variables (config, env, sender). Enforced: true.
  - `:guard_ast` - The quoted AST of the guard expression. Enforced: true.
  - `:action_ast` - The quoted AST of the action block (returns a list of effect tuples). Enforced: true.
  """
  typedstruct do
    field(:message_tag, atom(), enforce: true)
    field(:payload_bindings_ast, Macro.t(), enforce: true)
    field(:context_bindings_ast, Macro.t(), enforce: true)
    field(:guard_ast, Macro.t(), enforce: true)
    field(:action_ast, Macro.t(), enforce: true)
  end
end
