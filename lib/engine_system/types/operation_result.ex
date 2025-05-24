defmodule EngineSystem.Types.OperationResult do
  @moduledoc """
  **DEPRECATED:** This module will be removed in a future version. Use standard
  Elixir `{:ok, value} | {:error, reason}` patterns instead.

  I am a struct that conveys success or failure of various system actions,
  providing a value upon success or a reason upon failure.

  ## Public API

  - `ok/0`
  - `ok/1`
  - `error/1`
  """
  use TypedStruct

  typedstruct do
    @typedoc """
    I define the structure for an operation result.

    ## Fields

    - `:status` - The status of the operation. Enforced: true.
    - `:value` - The value returned by the operation (if successful). Default: `nil`.
    - `:reason` - The reason for failure (if unsuccessful). Default: `nil`.
    """
    field(:status, :ok | :error, enforce: true)
    field(:value, any(), default: nil)
    field(:reason, any(), default: nil)
  end

  @doc """
  I create a success result with an optional value.
  """
  @spec ok(value :: any()) :: %__MODULE__{status: :ok, value: any(), reason: nil}
  def ok(value \\ nil) do
    %__MODULE__{status: :ok, value: value}
  end

  @doc """
  I create an error result with a reason.
  """
  @spec error(reason :: any()) :: %__MODULE__{status: :error, value: nil, reason: any()}
  def error(reason) do
    %__MODULE__{status: :error, reason: reason}
  end
end
