defmodule EngineSystem.Engine.Compilation.Types.EngineSpec do
  @moduledoc """
  Defines the top-level specification for a compiled engine definition.
  """
  use TypedStruct

  alias EngineSystem.Engine.Compilation.Types.{
    BehaviourSpec,
    ConfigSpec,
    EnvSpec,
    MessageInterfaceSpec
  }

  @default_type_name nil
  @default_type_version "1.0"
  @default_config_spec %ConfigSpec{initial_value_ast: nil, module: nil}
  @default_env_spec %EnvSpec{initial_value_ast: nil, module: nil}
  @default_message_interface_spec %MessageInterfaceSpec{messages: []}
  @default_behaviour_spec %BehaviourSpec{guarded_actions: []}

  @typedoc """
  I am the top-level specification for a compiled engine definition.

  ### Fields
  - `:type_name` - The user-defined name of the engine type. If not specified,
    the Engine system assigns a name. Enforced: true.
  - `:type_version` - The user-defined version of this engine type. Enforced:
    true.
  - `:config_spec` - The specification for the engine's configuration. Enforced:
    true.
  - `:env_spec` - The specification for the engine's environment (local state).
    Enforced: true.
  - `:message_interface_spec` - The specification for the engine's messages.
    Enforced: true.
  - `:behaviour_spec` - The specification for the engine's behaviour (guarded
    actions). Enforced: true.
  """
  typedstruct do
    field(:type_name, atom(), enforce: true, default: @default_type_name)

    field(:type_version, String.t() | atom() | non_neg_integer(),
      enforce: true,
      default: @default_type_version
    )

    field(:config_spec, ConfigSpec.t(),
      enforce: true,
      default: @default_config_spec
    )

    field(:env_spec, EnvSpec.t(), enforce: true, default: @default_env_spec)

    field(:message_interface_spec, MessageInterfaceSpec.t(),
      enforce: true,
      default: @default_message_interface_spec
    )

    field(:behaviour_spec, BehaviourSpec.t(), enforce: true, default: @default_behaviour_spec)
  end
end
