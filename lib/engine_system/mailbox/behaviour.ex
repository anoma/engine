defmodule EngineSystem.Mailbox.Behaviour do
  @moduledoc """
  I define the standard behaviour interface for all mailbox engines.

  Both custom mailbox engines (defined with DSL) and the default mailbox engine
  must implement this behaviour to ensure consistent interaction with processing engines.

  This implements the mailbox-as-actors pattern where mailboxes are first-class
  actors that handle message validation, filtering, and delivery.
  """

  alias EngineSystem.System.Message

  @doc """
  I start a mailbox engine instance.

  ## Parameters

  - `mailbox_spec` - Map containing mailbox initialization data

  ## Returns

  GenServer start result.
  """
  @callback start_link(map()) :: GenServer.on_start()

  @doc """
  I enqueue a message according to the formal m-Enqueue rule.

  This validates the message against the processing engine's interface
  and stores it if valid.

  ## Parameters

  - `mailbox_pid` - The mailbox engine PID
  - `message` - The message to enqueue

  ## Returns

  - `:ok` if the message was enqueued successfully
  - `{:error, reason}` if the message could not be enqueued
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
