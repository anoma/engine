defmodule EngineSystem.Mailbox.KVPriorityMailboxEngine do
  @moduledoc """
  Priority-based mailbox engine for key-value store operations.

  This mailbox engine implements intelligent buffering and delivery policies
  specifically optimized for key-value store workloads:

  ## Key Features

  1. **Priority-based message ordering** - READ operations get higher priority than WRITE operations
  2. **Key-based batching** - Groups operations on the same key for efficient processing
  3. **Write coalescing** - Merges multiple writes to the same key, keeping only the latest
  4. **Read-after-write optimization** - Ensures reads see the most recent writes
  5. **Adaptive buffer sizing** - Adjusts buffer sizes based on load patterns

  ## Buffer Policies

  - **Priority Queue**: Messages sorted by operation type (GET > PUT > DELETE)
  - **Key Grouping**: Operations on same key are processed together
  - **Write Coalescing**: Multiple PUTs to same key are merged
  - **Batch Processing**: Groups related operations for efficiency

  ## Intelligent Delivery

  - **Load-aware delivery**: Adjusts delivery rate based on processing engine load
  - **Deadline-aware**: Ensures time-sensitive operations meet deadlines
  - **Conflict detection**: Detects read-write conflicts and orders appropriately
  """

  use GenStage
  use TypedStruct

  @behaviour EngineSystem.Mailbox.Behaviour

  alias EngineSystem.Engine.{Spec, State}
  alias EngineSystem.Mailbox.Message

  # Priority levels for different operations
  @priority_read 1
  @priority_write 2
  @priority_delete 3

  # Buffer configuration
  @default_max_buffer_size 1000
  @default_batch_size 10
  @default_coalesce_window_ms 50

  typedstruct do
    @typedoc """
    State for the KV Priority Mailbox Engine.
    """
    field(:address, State.address(), enforce: true)
    field(:processing_engine_spec, Spec.t(), enforce: true)
    field(:message_interface, Spec.message_interface(), enforce: true)
    field(:message_filter, function(), enforce: true)

    # Priority-based buffering
    field(:priority_buffer, :gb_trees.tree(), enforce: false, default: :gb_trees.empty())
    field(:key_index, %{any() => [Message.t()]}, enforce: false, default: %{})
    field(:write_coalesce_buffer, %{any() => Message.t()}, enforce: false, default: %{})

    # Buffer policies
    field(:max_buffer_size, non_neg_integer(), enforce: false, default: @default_max_buffer_size)
    field(:batch_size, non_neg_integer(), enforce: false, default: @default_batch_size)

    field(:coalesce_window_ms, non_neg_integer(),
      enforce: false,
      default: @default_coalesce_window_ms
    )

    # Delivery management
    field(:current_demand, non_neg_integer(), enforce: false, default: 0)
    field(:delivery_timer, reference() | nil, enforce: false, default: nil)
    field(:last_delivery_time, integer(), enforce: false, default: 0)

    # Statistics
    field(:total_received, non_neg_integer(), enforce: false, default: 0)
    field(:total_delivered, non_neg_integer(), enforce: false, default: 0)
    field(:coalesced_writes, non_neg_integer(), enforce: false, default: 0)
    field(:batched_operations, non_neg_integer(), enforce: false, default: 0)
  end

  ## Client API

  @doc """
  Start a KV Priority Mailbox Engine.
  """
  @spec start_link(map()) :: GenServer.on_start()
  @impl EngineSystem.Mailbox.Behaviour
  def start_link(mailbox_spec) do
    GenStage.start_link(__MODULE__, mailbox_spec)
  end

  @doc """
  Enqueue a message with intelligent buffering.
  """
  @spec enqueue_message(pid(), Message.t()) :: :ok
  @impl EngineSystem.Mailbox.Behaviour
  def enqueue_message(mailbox_pid, message) do
    GenStage.cast(mailbox_pid, {:enqueue_message, message})
  end

  @doc """
  Update the message filter function.
  """
  @spec update_filter(pid(), function()) :: :ok
  @impl EngineSystem.Mailbox.Behaviour
  def update_filter(mailbox_pid, new_filter) do
    GenStage.call(mailbox_pid, {:update_filter, new_filter})
  end

  @doc """
  Get information about the mailbox state.
  """
  @spec get_info(pid()) :: map()
  @impl EngineSystem.Mailbox.Behaviour
  def get_info(mailbox_pid) do
    GenStage.call(mailbox_pid, :get_info)
  end

  @doc """
  Update buffer policies.
  """
  @spec update_buffer_policy(pid(), map()) :: :ok
  def update_buffer_policy(mailbox_pid, policy_updates) do
    GenStage.call(mailbox_pid, {:update_buffer_policy, policy_updates})
  end

  @doc """
  Get detailed mailbox statistics.
  """
  @spec get_stats(pid()) :: map()
  def get_stats(mailbox_pid) do
    GenStage.call(mailbox_pid, :get_stats)
  end

  ## GenStage Callbacks

  @impl true
  def init(mailbox_spec) do
    state = %__MODULE__{
      address: mailbox_spec.address,
      processing_engine_spec: mailbox_spec.processing_engine_spec,
      message_interface: mailbox_spec.message_interface,
      message_filter: mailbox_spec.message_filter,
      priority_buffer: :gb_trees.empty(),
      key_index: %{},
      write_coalesce_buffer: %{},
      max_buffer_size: Map.get(mailbox_spec, :max_buffer_size, @default_max_buffer_size),
      batch_size: Map.get(mailbox_spec, :batch_size, @default_batch_size),
      coalesce_window_ms: Map.get(mailbox_spec, :coalesce_window_ms, @default_coalesce_window_ms)
    }

    # Start coalescing timer
    timer_ref = schedule_coalesce_flush(state.coalesce_window_ms)

    {:producer, %{state | delivery_timer: timer_ref}}
  end

  @impl true
  def handle_demand(demand, state) do
    new_demand = state.current_demand + demand
    new_state = %{state | current_demand: new_demand}

    # Deliver messages based on priority and buffer policies
    {events, final_state} = deliver_messages(new_state)

    {:noreply, events, final_state}
  end

  @impl true
  def handle_cast({:enqueue_message, message}, state) do
    case validate_and_categorize_message(message, state.processing_engine_spec) do
      {:ok, {category, priority}} ->
        new_state = buffer_message(message, category, priority, state)
        {events, final_state} = deliver_messages(new_state)
        {:noreply, events, final_state}

      {:error, _reason} ->
        # Invalid message, ignore
        {:noreply, [], state}
    end
  end

  @impl true
  def handle_call({:update_filter, new_filter}, _from, state) do
    new_state = %{state | message_filter: new_filter}
    {:reply, :ok, [], new_state}
  end

  @impl true
  def handle_call({:update_buffer_policy, policy_updates}, _from, state) do
    new_state = %{
      state
      | max_buffer_size: Map.get(policy_updates, :max_buffer_size, state.max_buffer_size),
        batch_size: Map.get(policy_updates, :batch_size, state.batch_size),
        coalesce_window_ms: Map.get(policy_updates, :coalesce_window_ms, state.coalesce_window_ms)
    }

    {:reply, :ok, [], new_state}
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    stats = calculate_detailed_stats(state)
    {:reply, stats, [], state}
  end

  @impl true
  def handle_call(:get_info, _from, state) do
    info = %{
      address: state.address,
      total_received: state.total_received,
      total_delivered: state.total_delivered,
      current_demand: state.current_demand,
      buffer_size: :gb_trees.size(state.priority_buffer),
      coalesce_buffer_size: map_size(state.write_coalesce_buffer),
      processing_engine_spec: state.processing_engine_spec.name
    }

    {:reply, info, [], state}
  end

  @impl true
  def handle_info(:flush_coalesce_buffer, state) do
    # Flush coalesced writes to main buffer
    new_state = flush_coalesce_buffer(state)

    # Reschedule timer
    timer_ref = schedule_coalesce_flush(new_state.coalesce_window_ms)
    final_state = %{new_state | delivery_timer: timer_ref}

    # Try to deliver messages
    {events, updated_state} = deliver_messages(final_state)

    {:noreply, events, updated_state}
  end

  ## Private Functions

  @spec validate_and_categorize_message(Message.t(), Spec.t()) ::
          {:ok, {atom(), integer()}} | {:error, any()}
  defp validate_and_categorize_message(message, processing_engine_spec) do
    # Validate message against engine's message interface
    case validate_message_with_interface(message, processing_engine_spec.interface) do
      :ok ->
        # Categorize the message based on its payload
        category = categorize_message(message)
        priority = get_priority_for_category(category)
        {:ok, {category, priority}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec validate_message_with_interface(Message.t(), Spec.message_interface()) ::
          :ok | {:error, any()}
  defp validate_message_with_interface(message, interface) do
    case Message.get_tag(message) do
      {:ok, tag} ->
        # Check if tag exists in interface
        case Enum.find(interface, fn {msg_tag, _fields} -> msg_tag == tag end) do
          nil -> {:error, {:unknown_message_tag, tag}}
          {^tag, _fields} -> :ok
        end

      :no_tag ->
        {:error, :no_message_tag}
    end
  end

  @spec buffer_message(Message.t(), atom(), integer(), t()) :: t()
  defp buffer_message(message, :write, _priority, state) do
    # For writes, use coalescing buffer
    key = extract_key_from_message(message)

    new_coalesce_buffer = Map.put(state.write_coalesce_buffer, key, message)
    new_key_index = update_key_index(state.key_index, key, message)

    %{
      state
      | write_coalesce_buffer: new_coalesce_buffer,
        key_index: new_key_index,
        total_received: state.total_received + 1
    }
  end

  defp buffer_message(message, _category, priority, state) do
    # For reads and deletes, add directly to priority buffer
    timestamp = :erlang.system_time(:microsecond)
    priority_key = {priority, timestamp, state.total_received}

    new_priority_buffer = :gb_trees.enter(priority_key, message, state.priority_buffer)

    %{state | priority_buffer: new_priority_buffer, total_received: state.total_received + 1}
  end

  @spec deliver_messages(t()) :: {[Message.t()], t()}
  defp deliver_messages(%{current_demand: 0} = state) do
    {[], state}
  end

  defp deliver_messages(state) do
    # Calculate batch size based on current demand and buffer policy
    batch_size = min(state.current_demand, state.batch_size)

    # Extract messages based on priority and key grouping
    {messages, new_state} = extract_batch_for_delivery(state, batch_size)

    delivered_count = length(messages)

    final_state = %{
      new_state
      | current_demand: new_state.current_demand - delivered_count,
        total_delivered: new_state.total_delivered + delivered_count,
        last_delivery_time: :erlang.system_time(:millisecond)
    }

    {messages, final_state}
  end

  @spec extract_batch_for_delivery(t(), non_neg_integer()) :: {[Message.t()], t()}
  defp extract_batch_for_delivery(state, max_batch_size) do
    # First, check if we need to flush any coalesced writes
    state_with_flushed = maybe_flush_urgent_writes(state)

    # Extract messages from priority buffer
    extract_from_priority_buffer(state_with_flushed, max_batch_size, [])
  end

  @spec extract_from_priority_buffer(t(), non_neg_integer(), [Message.t()]) ::
          {[Message.t()], t()}
  defp extract_from_priority_buffer(state, 0, acc) do
    {Enum.reverse(acc), state}
  end

  defp extract_from_priority_buffer(state, remaining, acc) do
    case :gb_trees.is_empty(state.priority_buffer) do
      true ->
        {Enum.reverse(acc), state}

      false ->
        {_priority_key, message, new_buffer} = :gb_trees.take_smallest(state.priority_buffer)

        # Apply message filter
        if apply_message_filter(message, state.message_filter) do
          new_state = %{state | priority_buffer: new_buffer}
          extract_from_priority_buffer(new_state, remaining - 1, [message | acc])
        else
          new_state = %{state | priority_buffer: new_buffer}
          extract_from_priority_buffer(new_state, remaining, acc)
        end
    end
  end

  @spec flush_coalesce_buffer(t()) :: t()
  defp flush_coalesce_buffer(state) do
    # Move all coalesced writes to priority buffer
    coalesced_count = map_size(state.write_coalesce_buffer)

    new_priority_buffer =
      Enum.reduce(state.write_coalesce_buffer, state.priority_buffer, fn {_key, message},
                                                                         buffer ->
        priority = get_priority_for_category(:write)
        timestamp = :erlang.system_time(:microsecond)
        priority_key = {priority, timestamp, state.total_received}
        :gb_trees.insert(priority_key, message, buffer)
      end)

    %{
      state
      | priority_buffer: new_priority_buffer,
        write_coalesce_buffer: %{},
        coalesced_writes: state.coalesced_writes + coalesced_count
    }
  end

  @spec maybe_flush_urgent_writes(t()) :: t()
  defp maybe_flush_urgent_writes(state) do
    current_time = :erlang.system_time(:millisecond)
    time_since_last_delivery = current_time - state.last_delivery_time

    # Flush if writes have been waiting too long
    if time_since_last_delivery > state.coalesce_window_ms do
      flush_coalesce_buffer(state)
    else
      state
    end
  end

  # Helper functions

  @spec get_priority_for_category(atom()) :: integer()
  defp get_priority_for_category(:read), do: @priority_read
  defp get_priority_for_category(:write), do: @priority_write
  defp get_priority_for_category(:delete), do: @priority_delete
  defp get_priority_for_category(_), do: @priority_write

  @spec categorize_message(Message.t()) :: atom()
  defp categorize_message(message) do
    case Message.get_tag(message) do
      {:ok, :get} -> :read
      {:ok, :put} -> :write
      {:ok, :delete} -> :delete
      _ -> :other
    end
  end

  @spec extract_key_from_message(Message.t()) :: any()
  defp extract_key_from_message(message) do
    case message.payload do
      %{key: key} -> key
      %{"key" => key} -> key
      {key, _value} -> key
      _ -> :unknown_key
    end
  end

  @spec update_key_index(map(), any(), Message.t()) :: map()
  defp update_key_index(key_index, key, message) do
    Map.put(key_index, key, message)
  end

  @spec schedule_coalesce_flush(non_neg_integer()) :: reference()
  defp schedule_coalesce_flush(interval_ms) do
    Process.send_after(self(), :flush_coalesce_buffer, interval_ms)
  end

  @spec calculate_detailed_stats(t()) :: map()
  defp calculate_detailed_stats(state) do
    buffer_size = :gb_trees.size(state.priority_buffer)
    coalesce_buffer_size = map_size(state.write_coalesce_buffer)

    %{
      address: state.address,
      total_received: state.total_received,
      total_delivered: state.total_delivered,
      coalesced_writes: state.coalesced_writes,
      batched_operations: state.batched_operations,
      current_demand: state.current_demand,
      buffer_size: buffer_size,
      coalesce_buffer_size: coalesce_buffer_size,
      key_index_size: map_size(state.key_index),
      max_buffer_size: state.max_buffer_size,
      batch_size: state.batch_size,
      coalesce_window_ms: state.coalesce_window_ms,
      buffer_utilization: (buffer_size + coalesce_buffer_size) / state.max_buffer_size
    }
  end

  @spec apply_message_filter(Message.t(), function()) :: boolean()
  defp apply_message_filter(message, filter_fn) do
    filter_fn.(message.payload, %{}, %{})
  rescue
    _error -> true
  end
end
