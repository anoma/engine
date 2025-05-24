defmodule EngineSystem.Types.EngineTypeInfo do
  @moduledoc """
  I represent the detailed specification of a registered engine type.

  This includes its name, version, the module where its full definition is compiled,
  and specifications for its configuration, environment, and message interface.

  ### Public API

  I have the following public functionality (primarily the struct fields):

  - `:name`
  - `:version`
  - `:definition_module`
  - `:config_spec`
  - `:env_spec`
  - `:message_interface_spec`
  - `:behaviour_spec`
  - `:registration_timestamp`
  """
  use TypedStruct

  alias EngineSystem.Engine.Compilation.Types.{
    BehaviourSpec,
    ConfigSpec,
    EnvSpec,
    MessageInterfaceSpec
  }

  @type timestamp :: integer()

  typedstruct do
    @typedoc """
    I define the structure for registered engine type information.

    ### Fields

    - `:name` - The unique name of the engine type. Enforced: true.
    - `:version` - The version of this engine type definition. Enforced: true.
    - `:definition_module` - The module where the compiled `EngineSpec` for this
      type and version resides. Enforced: true.
    - `:config_spec` - The specification for the engine's configuration
      structure. Enforced: true.
    - `:env_spec` - The specification for the engine's environment (local state)
      structure. Enforced: true.
    - `:message_interface_spec` - The specification for the messages this engine
      type can handle. Enforced: true.
    - `:behaviour_spec` - The specification for the engine's behaviour (guarded
      actions). Enforced: true.
      system (milliseconds since epoch). Enforced: true.
    - `:operation_mode` - The mode of operation: either :processing for a
      processing engine or :mailbox for a mailbox engine. Enforced: true.
    """
    field(:name, atom(), enforce: true)
    field(:version, String.t() | atom() | non_neg_integer(), enforce: true, default: "1.0")
    field(:definition_module, module(), enforce: true)
    field(:config_spec, ConfigSpec.t(), enforce: true)
    field(:env_spec, EnvSpec.t(), enforce: true)
    field(:message_interface_spec, MessageInterfaceSpec.t(), enforce: true)
    field(:behaviour_spec, BehaviourSpec.t(), enforce: true)
    field(:registration_timestamp, timestamp(), enforce: true)
  end
end
