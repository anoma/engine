defmodule EngineSystem.SystemInfo do
  @moduledoc """
  I represent a snapshot of the Engine System's overall status and configuration.

  This includes versioning information, summaries of registered types, and counts of running instances.

  ### Public API

  I have the following public functionality (primarily the struct fields):

  - `:system_version`
  - `:library_version`
  - `:registered_engine_types_summary`
  - `:running_instances_count`
  - `:started_at`
  """
  use TypedStruct

  typedstruct do
    @typedoc """
    I define the structure for system information.

    ### Fields

    - `:system_version` - The operational version of the currently running system logic/configuration. Enforced: true.
    - `:library_version` - The version of the EngineSystem library code. Enforced: true.
    - `:registered_engine_types_summary` - A summary of engine types registered with the system (e.g., a map of type_name to version list or count). Enforced: true.
    - `:running_instances_count` - The total number of currently active engine instances. Enforced: true.
    - `:started_at` - The timestamp when the system was started. Enforced: true.
    """
    field(:system_version, String.t(), enforce: true)
    field(:library_version, String.t(), enforce: true)
    field(:registered_engine_types_summary, map(), enforce: true, default: %{})
    field(:running_instances_count, non_neg_integer(), enforce: true, default: 0)
    field(:started_at, DateTime.t(), enforce: true)
  end
end
