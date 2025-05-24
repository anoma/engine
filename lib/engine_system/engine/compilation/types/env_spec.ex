defmodule EngineSystem.Engine.Compilation.Types.EnvSpec do
  @moduledoc """
  Defines the structure for an engine's environment (local state).
  """
  use TypedStruct

  @default_module nil
  @default_initial_value_ast nil

  @typedoc """
  I specify the environment (local state) structure for an engine type.

  The address book (mapping names to addresses, including `:self`) is part of this state.

  ### Fields
  - `:module` - The Elixir struct module defining the environment. May be nil if not a struct. Enforced: false.
  - `:initial_value_ast` - The quoted AST for the initial value of the environment. Enforced: true.
  """
  typedstruct do
    field(:module, module() | nil, default: @default_module)

    field(:initial_value_ast, Macro.t(),
      enforce: true,
      default: @default_initial_value_ast
    )
  end
end
