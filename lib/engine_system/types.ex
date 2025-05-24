defmodule EngineSystem.Types do
  @moduledoc """
  I provide consolidated access to all EngineSystem type definitions.

  This module provides convenient aliases for all type modules used
  throughout the EngineSystem.
  """

  # Public types commonly used by consumers
  alias EngineSystem.Types.EngineStatus

  # Re-export commonly used types for convenience
  defdelegate default_filter(), to: EngineStatus
  defdelegate default_filter(envelope), to: EngineStatus

  # Type definitions for the EngineSystem

  @typedoc """
  I define the standard result type for EngineSystem operations.

  Returns either `{:ok, value}` on success or `{:error, reason}` on failure.
  """
  @type result(success_type) :: {:ok, success_type} | {:error, any()}

  @typedoc """
  I define the standard result type with no success value.
  """
  @type result() :: :ok | {:error, any()}

  @typedoc """
  I define the engine address type.
  """
  @type address :: any()

  @typedoc """
  I define the engine type specification format.
  """
  @type engine_type :: {atom() | String.t(), String.t()}

  @typedoc """
  I define the message format.
  """
  @type message :: {atom(), any()}
end
