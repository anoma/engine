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
  """
  @callback update_filter(pid(), function()) :: :ok | {:error, any()}

  @doc """
  I get information about the mailbox state.
  """
  @callback get_info(pid()) :: map()
end
