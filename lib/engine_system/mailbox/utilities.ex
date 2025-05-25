defmodule EngineSystem.Mailbox.Utilities do
  @moduledoc """
  I provide utility functions for mailbox operations.

  This module contains common functionality extracted from the mailbox engine
  to improve code organization and reduce complexity.
  """

  alias EngineSystem.Engine.Spec
  alias EngineSystem.Mailbox.Message

  @doc """
  I validate a message against a message interface.

  ## Parameters

  - `message` - The message to validate
  - `interface` - The message interface specification

  ## Returns

  - `:ok` if the message is valid
  - `{:error, reason}` if the message is invalid
  """
  @spec validate_message_interface(Message.t(), Spec.message_interface()) ::
          :ok | {:error, String.t()}
  def validate_message_interface(%Message{payload: payload}, interface) do
    case extract_message_tag(payload) do
      {:ok, tag} -> validate_tag_in_interface(tag, interface)
      error -> error
    end
  end

  @doc """
  I extract the message tag from a payload.

  ## Parameters

  - `payload` - The message payload

  ## Returns

  - `{:ok, tag}` if a tag can be extracted
  - `{:error, reason}` if no tag can be extracted
  """
  @spec extract_message_tag(any()) :: {:ok, atom()} | {:error, String.t()}
  def extract_message_tag({tag, _data}) when is_atom(tag), do: {:ok, tag}
  def extract_message_tag(tag) when is_atom(tag), do: {:ok, tag}
  def extract_message_tag(_), do: {:error, "Cannot extract message tag"}

  @doc """
  I validate that a tag exists in the message interface.

  ## Parameters

  - `tag` - The message tag to validate
  - `interface` - The message interface specification

  ## Returns

  - `:ok` if the tag is valid
  - `{:error, reason}` if the tag is invalid
  """
  @spec validate_tag_in_interface(atom(), Spec.message_interface()) ::
          :ok | {:error, String.t()}
  def validate_tag_in_interface(tag, interface) do
    interface_tags = Enum.map(interface, fn {interface_tag, _fields} -> interface_tag end)

    if tag in interface_tags do
      :ok
    else
      {:error, "Message tag #{tag} not found in interface"}
    end
  end

  @doc """
  I apply a message filter to determine if a message should be processed.

  ## Parameters

  - `message` - The message to filter
  - `filter_func` - The filter function
  - `config` - Engine configuration (optional)
  - `env` - Engine environment (optional)

  ## Returns

  - `true` if the message should be processed
  - `false` if the message should be filtered out
  """
  @spec apply_message_filter(Message.t(), function(), any(), any()) :: boolean()
  def apply_message_filter(message, filter_func, config \\ nil, env \\ nil) do
    case :erlang.fun_info(filter_func, :arity) do
      {:arity, 1} -> filter_func.(message)
      {:arity, 3} -> filter_func.(message, config, env)
      {:arity, 4} -> filter_func.(message, config, env, nil)
      # Default to accepting if arity doesn't match
      _ -> true
    end
  rescue
    # Default to accepting if filter fails
    _ -> true
  end

  @doc """
  I calculate queue statistics for monitoring purposes.

  ## Parameters

  - `queue` - The message queue
  - `total_received` - Total messages received
  - `total_delivered` - Total messages delivered

  ## Returns

  A map with queue statistics.
  """
  @spec calculate_queue_stats(:queue.queue(), non_neg_integer(), non_neg_integer()) :: map()
  def calculate_queue_stats(queue, total_received, total_delivered) do
    queue_size = :queue.len(queue)

    %{
      queue_size: queue_size,
      total_received: total_received,
      total_delivered: total_delivered,
      pending_messages: queue_size,
      processing_rate: calculate_processing_rate(total_received, total_delivered)
    }
  end

  # Private helper functions

  defp calculate_processing_rate(0, _), do: 0.0

  defp calculate_processing_rate(received, delivered) do
    Float.round(delivered / received * 100, 2)
  end
end
