defmodule EngineSystem.System.SystemInfo do
  @moduledoc """
  I provide system-wide information and statistics.

  I'm responsible for:
  - Collecting system information
  - Providing system statistics
  - Managing system metadata
  """

  alias EngineSystem.Types.SystemInfo

  @type system_version :: String.t()
  @type timestamp :: integer()

  @type state :: %{
          system_version: system_version(),
          system_started_at: timestamp()
        }

  @doc """
  I initialize the system information state.

  ## Returns

  - `state()` - Initial system information state
  """
  @spec init() :: state()
  def init do
    %{
      system_version: "0.1.0",
      system_started_at: System.system_time(:millisecond)
    }
  end

  @doc """
  I get comprehensive system information.

  ## Parameters

  - `state` - The current system state
  - `_engine_type_count` - Number of registered engine types (unused for now)
  - `engine_instance_count` - Number of active engine instances

  ## Returns

  - `{:ok, system_info}` - System information
  """
  @spec get_system_info(state(), non_neg_integer(), non_neg_integer()) ::
          {:ok, SystemInfo.t()}
  def get_system_info(state, _engine_type_count, engine_instance_count) do
    started_at_datetime = DateTime.from_unix!(state.system_started_at, :millisecond)

    system_info = %SystemInfo{
      system_version: state.system_version,
      library_version: state.system_version,
      registered_engine_types_summary: %{},
      running_instances_count: engine_instance_count,
      started_at: started_at_datetime
    }

    {:ok, system_info}
  end

  @doc """
  I get the system version.

  ## Parameters

  - `state` - The current system state

  ## Returns

  - `system_version()` - The system version
  """
  @spec get_version(state()) :: system_version()
  def get_version(state) do
    state.system_version
  end

  @doc """
  I get the system uptime in milliseconds.

  ## Parameters

  - `state` - The current system state

  ## Returns

  - `non_neg_integer()` - Uptime in milliseconds
  """
  @spec get_uptime(state()) :: non_neg_integer()
  def get_uptime(state) do
    current_time = System.system_time(:millisecond)
    current_time - state.system_started_at
  end

  # Private helper functions

  # Note: get_memory_usage function removed as it was unused
  # Can be re-added when needed for system monitoring features
end
