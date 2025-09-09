defmodule EngineSystem.Mailbox.Behaviour do
  @moduledoc """
  I define the standard behaviour interface for all mailbox engines in the mailbox-as-actors pattern.
  """

  alias EngineSystem.System.Message

  @doc """
  I start a mailbox engine instance.
  """
  @callback start_link(map()) :: GenServer.on_start()

  @doc """
  I enqueue a message with validation against the processing engine's interface.
  """
  @callback enqueue_message(pid(), Message.t()) :: :ok | {:error, any()}

  @doc """
  I update the message filter function.

  This is called when the processing engine changes its filter
  (e.g., when using the mfilter effect).

  ## Parameters

  - `mailbox_pid` - The mailbox engine PID
  - `new_filter` - The new message filter function

  ## Returns

  - `:ok` if the filter was updated successfully
  - `{:error, reason}` if the update failed
  """
  @callback update_filter(pid(), function()) :: :ok | {:error, any()}

  @doc """
  I get information about the mailbox state.

  ## Parameters

  - `mailbox_pid` - The mailbox engine PID

  ## Returns

  Map containing mailbox state information.
  """
  @callback get_info(pid()) :: map()
end
