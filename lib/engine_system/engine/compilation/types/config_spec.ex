defmodule EngineSystem.Engine.Compilation.Types.ConfigSpec do
  @moduledoc """
  Defines the structure for an engine type's configuration.
  """
  use TypedStruct

  @default_module nil
  @default_initial_value_ast nil

  @typedoc """
  I specify the configuration structure for an engine type.

  ### Fields
  - `:module` - The Elixir struct module defining the configuration. May be nil if not a struct. Enforced: false.
  - `:initial_value_ast` - The quoted AST for the initial value of the configuration. Enforced: true.
  """
  typedstruct do
    field(
      :module,
      module() | nil,
      default: @default_module
    )

    field(:initial_value_ast, Macro.t(),
      enforce: true,
      default: @default_initial_value_ast
    )
  end
end
