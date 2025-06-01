defmodule EngineSystem.Engine do
  @moduledoc """
  I provide DSL and utility functions for engine development.

  **Note**: This module is primarily used internally by the EngineSystem library.
  For end users, the recommended approach is to use `use EngineSystem` which
  provides access to all functionality including DSL macros, utilities, and API functions.

  ```elixir
  use EngineSystem

  defengine MyEngine do
    version "1.0.0"
    # ... rest of engine definition
  end
  ```

  If you specifically need only the utilities from this module without the DSL
  or API functions, you can still use `use EngineSystem.Engine`:

  ```elixir
  use EngineSystem.Engine

  # This gives you access to:
  # - DSL macros (defengine, version, etc.)
  # - Utility functions (validate_message_for_pe, extract_messages, etc.)
  # But NOT the API functions (spawn_engine, send_message, etc.)
  ```

  However, the `use EngineSystem` approach is preferred as it provides the complete
  interface in a single import, following Elixir library conventions.

  ## Exported Functions

  This module provides utility functions that are commonly needed
  across different engine implementations:

  - `validate_message_for_pe/2` - Validate messages against processing engine specs
  - `extract_messages/3` - Extract messages from queues with filtering
  - `apply_filter/2` - Apply message filters safely
  - `extract_message_tag/1` - Extract message tags from payloads
  - `validate_address/1` - Validate engine address format
  - `fresh_id/0` - Generate unique identifiers
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
  I validate a message against a processing engine specification.

  ## Parameters

  - `message` - The message to validate (should have a payload field)
  - `pe_spec` - The processing engine specification

  ## Returns

  - `:ok` if the message is valid
  - `{:error, reason}` if the message is invalid

  ## Examples

      iex> message = %{payload: {:get, %{key: "test"}}}
      iex> pe_spec = %{interface: [get: [:key], put: [:key, :value]]}
      iex> EngineSystem.Engine.validate_message_for_pe(message, pe_spec)
      :ok

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
  I extract the message tag from a payload.

  ## Parameters

  - `payload` - The message payload

  ## Returns

  - `{:ok, tag}` if a tag can be extracted
  - `{:error, reason}` if no tag can be extracted

  ## Examples

      iex> EngineSystem.Engine.extract_message_tag({:get, %{key: "test"}})
      {:ok, :get}

      iex> EngineSystem.Engine.extract_message_tag(:ping)
      {:ok, :ping}

      iex> EngineSystem.Engine.extract_message_tag("invalid")
      {:error, "Cannot extract message tag"}

  """
  @spec extract_message_tag(any()) :: {:ok, atom()} | {:error, String.t()}
  def extract_message_tag({tag, _data}) when is_atom(tag), do: {:ok, tag}
  def extract_message_tag(tag) when is_atom(tag), do: {:ok, tag}
  def extract_message_tag(_), do: {:error, "Cannot extract message tag"}

  @doc """
  I validate an engine address format.

  ## Parameters

  - `address` - The address to validate

  ## Returns

  - `:ok` if the address is valid
  - `{:error, reason}` if the address is invalid

  ## Examples

      iex> EngineSystem.Engine.validate_address({0, 123})
      :ok

      iex> EngineSystem.Engine.validate_address("invalid")
      {:error, "Invalid address format"}

  """
  @spec validate_address(any()) :: :ok | {:error, String.t()}
  def validate_address({node_id, engine_id})
      when is_integer(node_id) and node_id >= 0 and
             is_integer(engine_id) and engine_id >= 0 do
    :ok
  end

  def validate_address(_), do: {:error, "Invalid address format"}

  @doc """
  I generate a unique identifier for engine instances, messages, etc.

  This delegates to the system services for ID generation.

  ## Returns

  A unique integer identifier.

  ## Examples

      iex> id1 = EngineSystem.Engine.fresh_id()
      iex> id2 = EngineSystem.Engine.fresh_id()
      iex> id1 != id2
      true

  """
  @spec fresh_id() :: non_neg_integer()
  def fresh_id do
    :erlang.unique_integer([:positive])
  end

  @doc """
  I extract messages from a queue with demand limiting and filtering.

  ## Parameters

  - `queue` - The Erlang queue to extract from
  - `demand` - The maximum number of messages to extract
  - `filter` - The filter function to apply (can be nil)

  ## Returns

  A tuple `{messages, remaining_queue}` where:
  - `messages` - List of extracted messages that passed the filter
  - `remaining_queue` - The queue with remaining messages

  ## Examples

      iex> queue = :queue.from_list([msg1, msg2, msg3])
      iex> filter = fn msg, _, _ -> true end
      iex> {messages, _} = EngineSystem.Engine.extract_messages(queue, 2, filter)
      iex> length(messages)
      2

  """
  @spec extract_messages(:queue.queue(), non_neg_integer(), function() | nil) ::
          {list(), :queue.queue()}
  def extract_messages(queue, demand, filter) do
    extract_messages_recursive(queue, demand, filter, [])
  end

  @doc """
  I apply a message filter safely with error handling.

  ## Parameters

  - `filter` - The filter function (can be nil)
  - `message` - The message to filter

  ## Returns

  - `true` if the message should be processed
  - `false` if the message should be filtered out

  ## Examples

      iex> filter = fn msg, _, _ -> msg.important end
      iex> message = %{important: true}
      iex> EngineSystem.Engine.apply_filter(filter, message)
      true

  """
  @spec apply_filter(function() | nil, any()) :: boolean()
  def apply_filter(nil, _message), do: true

  def apply_filter(filter, message) do
    # Filter functions expect (message, config, env)
    # For simplicity, pass nils for config/env since filter
    # typically only looks at message content
    filter.(message, nil, nil)
  rescue
    # Default to accepting message if filter fails
    _ -> true
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
