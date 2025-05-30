defmodule EngineSystem.Mailbox.Behaviour do
  @moduledoc """
  Behavior that all mailbox engines must implement.

  This ensures consistency across different mailbox engine implementations
  while allowing for specialized message handling and buffering policies.
  """

  alias EngineSystem.Mailbox.Message

  @doc """
  Start a mailbox engine with the given specification.
  """
  @callback start_link(map()) :: GenServer.on_start()

  @doc """
  Enqueue a message for the processing engine.
  """
  @callback enqueue_message(pid(), Message.t()) :: :ok

  @doc """
  Update the message filter function.
  """
  @callback update_filter(pid(), function()) :: :ok

  @doc """
  Get information about the mailbox state.
  """
  @callback get_info(pid()) :: map()

  @optional_callbacks [update_filter: 2]
end
