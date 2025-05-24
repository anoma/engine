defmodule EngineSystem.Types.EngineInstanceInfo do
  @moduledoc """
  I represent detailed information about a running engine instance.

  This includes its address, PID, type, version, status, timestamps,
  operational mode, and mailbox size.

  ### Public API

  I have the following public functionality (primarily the struct fields):

  - `:address`
  - `:pid`
  - `:type_name`
  - `:type_version`
  - `:status`
  - `:creation_timestamp`
  - `:last_status_change_timestamp`
  - `:operational_mode`
  - `:mailbox_size`
  """
  use TypedStruct

  alias EngineSystem.Types.EngineMode
  alias EngineSystem.Types.EngineStatus
  alias EngineSystem.Types.MessageEnvelope

  @type timestamp :: integer()
  @type engine_address :: any()

  typedstruct do
    @typedoc """
    I define the structure for engine instance information.

    ### Fields

    - `:address` - The unique address of the engine instance. Enforced: true.
    - `:pid` - The process ID of the engine instance. Enforced: true.
    - `:type_name` - The name of the engine type. Enforced: true.
    - `:type_version` - The version of the engine type. Enforced: true.
    - `:status` - The current operational status of the engine. Enforced: true.
    - `:creation_timestamp` - Timestamp of when the engine instance was created.
      Enforced: true.
    - `:last_status_change_timestamp` - Timestamp of the last status change.
      Enforced: true.
    - `:operational_mode` - The operational mode of the engine (e.g., :process or :mail).
      Enforced: true.
    - `:mailbox_size` - The current number of messages in the engine's mailbox.
      Enforced: true.
    """
    field(:address, engine_address(), enforce: true)
    field(:pid, pid(), enforce: true)
    field(:type_name, atom() | String.t(), enforce: true)
    field(:type_version, String.t(), enforce: true)
    field(:status, EngineStatus.t(MessageEnvelope.t()), enforce: true)
    field(:creation_timestamp, timestamp(), enforce: true)
    field(:last_status_change_timestamp, timestamp(), enforce: true)
    field(:operational_mode, EngineMode.t(), enforce: true)
    field(:mailbox_size, non_neg_integer(), enforce: true)
  end
end
