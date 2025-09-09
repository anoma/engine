defmodule EngineSystem.Engine do
  @moduledoc """
  I provide DSL and utility functions for engine development.
  """

  @doc false
  defmacro __using__(_opts) do
    quote do
      # Import DSL macros
      import EngineSystem.Engine.DSL

      # Import utility functions
      import EngineSystem.Engine,
        only: [
          validate_message_for_pe: 2,
          extract_messages: 3,
          apply_filter: 2,
          extract_message_tag: 1,
          validate_address: 1,
          fresh_id: 0
        ]
    end
  end

  @doc """
  I validate a message against an engine spec.
  """
  @spec validate_message_for_pe(map(), map()) :: :ok | {:error, atom()}
  def validate_message_for_pe(message, pe_spec) do
    # Extract message tag
    message_tag =
      case message do
        %{payload: {tag, _}} -> tag
        %{payload: tag} when is_atom(tag) -> tag
        _ -> nil
      end

    if message_tag && pe_spec && pe_spec.interface do
      # Check if message tag is in processing engine interface
      valid_tag =
        Enum.any?(pe_spec.interface, fn
          {^message_tag, _} -> true
          _ -> false
        end)

      if valid_tag, do: :ok, else: {:error, :unknown_message_tag}
    else
      {:error, :invalid_message_format}
    end
  end

  @doc """
  I extract the message tag.
  """
  @spec extract_message_tag(any()) :: {:ok, atom()} | {:error, String.t()}
  def extract_message_tag({tag, _data}) when is_atom(tag), do: {:ok, tag}
  def extract_message_tag(tag) when is_atom(tag), do: {:ok, tag}
  def extract_message_tag(_), do: {:error, "Cannot extract message tag"}

  @doc """
  I validate an address format.
  """
  @spec validate_address(any()) :: :ok | {:error, String.t()}
  def validate_address({node_id, engine_id})
      when is_integer(node_id) and node_id >= 0 and
             is_integer(engine_id) and engine_id >= 0 do
    :ok
  end

  def validate_address(_), do: {:error, "Invalid address format"}

  @doc """
  I generate a unique identifier.
  """
  @spec fresh_id() :: non_neg_integer()
  def fresh_id do
    :erlang.unique_integer([:positive])
  end

  @doc """
  I extract messages from a queue.
  """
  @spec extract_messages(:queue.queue(), non_neg_integer(), function() | nil) ::
          {[any()], :queue.queue()}
  def extract_messages(queue, demand, filter) do
    extract_messages_recursive(queue, demand, filter, [])
  end

  @doc """
  I apply a filter function to a message.
  """
  @spec apply_filter(function() | nil, any()) :: boolean()
  def apply_filter(nil, _message), do: true

  def apply_filter(filter, message) do
    # Check function arity to determine how to call it
    info = :erlang.fun_info(filter, :arity)

    case info do
      {:arity, 1} ->
        try do
          filter.(message)
        rescue
          _ -> false
        catch
          _ -> false
        end

      {:arity, 3} ->
        try do
          filter.(message, nil, nil)
        rescue
          _ -> false
        catch
          _ -> false
        end

      _ ->
        # Default to 1-arity for backward compatibility
        try do
          filter.(message)
        rescue
          _ -> false
        catch
          _ -> false
        end
    end
  end

  # Private helper functions

  defp extract_messages_recursive(queue, demand, _filter, acc) when demand <= 0 do
    {Enum.reverse(acc), queue}
  end

  defp extract_messages_recursive(queue, demand, filter, acc) do
    case :queue.out(queue) do
      {{:value, message}, remaining_queue} ->
        # Apply filter
        if apply_filter(filter, message) do
          # Message passes filter
          extract_messages_recursive(remaining_queue, demand - 1, filter, [message | acc])
        else
          # Message filtered out, put back at end and continue
          new_queue = :queue.in(message, remaining_queue)
          extract_messages_recursive(new_queue, demand, filter, acc)
        end

      {:empty, empty_queue} ->
        {Enum.reverse(acc), empty_queue}
    end
  end
end
