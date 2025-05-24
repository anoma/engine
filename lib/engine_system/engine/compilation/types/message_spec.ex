defmodule EngineSystem.Engine.Compilation.Types.MessageSpec do
  @moduledoc """
  Defines the structure for a single message type in an engine's interface.
  """
  use TypedStruct

  @default_tag nil
  @default_payload_params_ast nil
  @default_payload_struct_module nil

  @typedoc """
  I specify a single message type within an engine's interface.

  ### Fields
  - `:tag` - The atom tag identifying this message type. Enforced: true.
  - `:payload_params_ast` - Quoted AST of parameters for the message payload (e.g., `[:key, :value]`). Enforced: false.
  - `:payload_struct_module` - Optional module defining a struct for the payload. Enforced: false.
  """
  typedstruct do
    field(
      :tag,
      atom(),
      enforce: true,
      default: @default_tag
    )

    field(:payload_params_ast, Macro.t() | nil, default: @default_payload_params_ast)
    field(:payload_struct_module, module() | nil, default: @default_payload_struct_module)
  end
end
