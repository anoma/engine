defmodule EngineSystem.Mailbox.MessageStore do
  @moduledoc """
  I implement message storage and retrieval policies for mailbox engines.

  According to the formal model, I maintain the local state L_m of mailbox engines
  with operations for message insertion and deletion based on delivery policies.

  Supported policies:
  - `:fifo` - First In, First Out (simple queue)
  - `:priority` - Priority-based delivery
  - `:key_based` - Key-based ordering (for key-value operations)
  - `{module, opts}` - Custom policy module
  """

  alias EngineSystem.Types.MessageEnvelope

  # --- Types --- #

  @type delivery_policy :: :fifo | :priority | :key_based | {module(), any()}
  @type t :: %__MODULE__{
          policy: delivery_policy(),
          messages: list(MessageEnvelope.t()) | :queue.queue(MessageEnvelope.t()) | any(),
          size: non_neg_integer()
        }

  @enforce_keys [:policy, :messages, :size]
  defstruct [:policy, :messages, :size]

  # --- Public API --- #

  @doc """
  I create a new message store with the given delivery policy.
  """
  @spec new(delivery_policy()) :: t()
  def new(policy \\ :fifo) do
    messages =
      case policy do
        :fifo -> :queue.new()
        :priority -> []
        :key_based -> %{keys: %{}, queue: :queue.new()}
        {_module, _opts} -> []
      end

    %__MODULE__{
      policy: policy,
      messages: messages,
      size: 0
    }
  end

  @doc """
  I insert a message according to the delivery policy.

  This implements the message insertion operation from the formal model.
  """
  @spec insert(t(), MessageEnvelope.t()) :: t()
  def insert(%__MODULE__{policy: :fifo} = store, message) do
    new_queue = :queue.in(message, store.messages)
    %{store | messages: new_queue, size: store.size + 1}
  end

  def insert(%__MODULE__{policy: :priority} = store, message) do
    # For priority, we'll use message timestamp as priority (older = higher priority)
    # In a real system, messages would have explicit priority fields
    new_messages = insert_by_priority(store.messages, message)
    %{store | messages: new_messages, size: store.size + 1}
  end

  def insert(%__MODULE__{policy: :key_based} = store, message) do
    # For key-based, we group by the key and maintain order within each key
    key = extract_key_from_message(message)

    %{keys: keys, queue: queue} = store.messages

    new_queue = :queue.in(message, queue)
    new_keys = Map.update(keys, key, [message], fn existing -> existing ++ [message] end)

    new_messages = %{keys: new_keys, queue: new_queue}
    %{store | messages: new_messages, size: store.size + 1}
  end

  def insert(%__MODULE__{policy: {module, opts}} = store, message) do
    # Delegate to custom policy module
    new_messages = apply(module, :insert, [store.messages, message, opts])
    %{store | messages: new_messages, size: store.size + 1}
  end

  @doc """
  I extract up to `count` messages according to the delivery policy.

  This implements the message deletion operation from the formal model.
  """
  @spec extract(t(), pos_integer()) :: {list(MessageEnvelope.t()), t()}
  def extract(%__MODULE__{size: 0} = store, _count) do
    {[], store}
  end

  def extract(%__MODULE__{policy: :fifo} = store, count) do
    {messages, new_queue} = extract_from_queue(store.messages, count, [])
    new_store = %{store | messages: new_queue, size: store.size - length(messages)}
    {messages, new_store}
  end

  def extract(%__MODULE__{policy: :priority} = store, count) do
    {messages, remaining} = Enum.split(store.messages, count)
    new_store = %{store | messages: remaining, size: store.size - length(messages)}
    {messages, new_store}
  end

  def extract(%__MODULE__{policy: :key_based} = store, count) do
    # For key-based, we try to deliver messages in key order to maintain consistency
    %{keys: keys, queue: queue} = store.messages

    {messages, new_queue} = extract_from_queue(queue, count, [])

    # Update the keys tracking by removing extracted messages
    new_keys =
      Enum.reduce(messages, keys, fn msg, acc ->
        key = extract_key_from_message(msg)

        case Map.get(acc, key, []) do
          [^msg | rest] ->
            if rest == [], do: Map.delete(acc, key), else: Map.put(acc, key, rest)

          existing ->
            Map.put(acc, key, List.delete(existing, msg))
        end
      end)

    new_messages = %{keys: new_keys, queue: new_queue}
    new_store = %{store | messages: new_messages, size: store.size - length(messages)}
    {messages, new_store}
  end

  def extract(%__MODULE__{policy: {module, opts}} = store, count) do
    # Delegate to custom policy module
    {messages, new_messages} = apply(module, :extract, [store.messages, count, opts])
    new_store = %{store | messages: new_messages, size: store.size - length(messages)}
    {messages, new_store}
  end

  @doc """
  I return the number of messages currently stored.
  """
  @spec size(t()) :: non_neg_integer()
  def size(%__MODULE__{size: size}), do: size

  @doc """
  I check if the store is empty.
  """
  @spec empty?(t()) :: boolean()
  def empty?(%__MODULE__{size: 0}), do: true
  def empty?(%__MODULE__{}), do: false

  # --- Private Functions --- #

  @spec extract_from_queue(
          :queue.queue(MessageEnvelope.t()),
          pos_integer(),
          list(MessageEnvelope.t())
        ) ::
          {list(MessageEnvelope.t()), :queue.queue(MessageEnvelope.t())}
  defp extract_from_queue(queue, 0, acc), do: {Enum.reverse(acc), queue}

  defp extract_from_queue(queue, count, acc) do
    case :queue.out(queue) do
      {{:value, message}, new_queue} ->
        extract_from_queue(new_queue, count - 1, [message | acc])

      {:empty, queue} ->
        {Enum.reverse(acc), queue}
    end
  end

  @spec insert_by_priority(list(MessageEnvelope.t()), MessageEnvelope.t()) ::
          list(MessageEnvelope.t())
  defp insert_by_priority([], message), do: [message]

  defp insert_by_priority([head | tail] = messages, message) do
    # Insert by timestamp (older messages have higher priority)
    if message.timestamp <= head.timestamp do
      [message | messages]
    else
      [head | insert_by_priority(tail, message)]
    end
  end

  @spec extract_key_from_message(MessageEnvelope.t()) :: any()
  defp extract_key_from_message(message) do
    # Extract key from message payload
    # This is a simplified implementation - in practice, you'd parse the message structure
    case message.original_payload do
      {:get, key} -> key
      {:put, key, _value} -> key
      {:delete, key} -> key
      {_tag, key, _rest} when is_binary(key) or is_atom(key) -> key
      _ -> :default_key
    end
  end
end
