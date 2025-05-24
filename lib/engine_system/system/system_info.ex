defmodule EngineSystem.System.SystemInfo do
  @moduledoc """
  I provide system-wide information and statistics.

  I'm responsible for:
  - Collecting system information
  - Providing system statistics
  - Managing system metadata
  """

  alias EngineSystem.Types.{OperationResult, SystemInfo}

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
  - `engine_type_count` - Number of registered engine types
  - `engine_instance_count` - Number of active engine instances

  ## Returns

  - `{:ok, system_info}` - System information
  """
  @spec get_system_info(state(), non_neg_integer(), non_neg_integer()) ::
          {:ok, SystemInfo.t()}
  def get_system_info(state, engine_type_count, engine_instance_count) do
    current_time = System.system_time(:millisecond)
    uptime_ms = current_time - state.system_started_at

    system_info = %SystemInfo{
      library_version: state.system_version,
      system_started_at: state.system_started_at,
      uptime_milliseconds: uptime_ms,
      registered_engine_types: engine_type_count,
      active_engine_instances: engine_instance_count,
      node_name: node(),
      erlang_version: System.version(),
      memory_usage: get_memory_usage(),
      process_count: Process.list() |> length()
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

  @spec get_memory_usage() :: %{
          total: non_neg_integer(),
          processes: non_neg_integer(),
          system: non_neg_integer(),
          atom: non_neg_integer(),
          binary: non_neg_integer(),
          code: non_neg_integer(),
          ets: non_neg_integer()
        }
  defp get_memory_usage do
    memory_info = :erlang.memory()

    %{
      total: Keyword.get(memory_info, :total, 0),
      processes: Keyword.get(memory_info, :processes, 0),
      system: Keyword.get(memory_info, :system, 0),
      atom: Keyword.get(memory_info, :atom, 0),
      binary: Keyword.get(memory_info, :binary, 0),
      code: Keyword.get(memory_info, :code, 0),
      ets: Keyword.get(memory_info, :ets, 0)
    }
  end
end
