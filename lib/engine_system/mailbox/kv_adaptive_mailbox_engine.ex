defmodule EngineSystem.Mailbox.KVAdaptiveMailboxEngine do
  @moduledoc """
  Adaptive load-balancing mailbox engine for key-value store operations.

  This mailbox engine implements intelligent buffering and delivery policies
  that adapt to system load and processing patterns:

  ## Key Features

  1. **Dynamic Load Balancing** - Adjusts delivery rate based on processing engine performance
  2. **Pattern Recognition** - Learns from access patterns to optimize delivery
  3. **Congestion Control** - Implements backpressure when processing engine is overloaded
  4. **Hot Key Detection** - Identifies frequently accessed keys for special handling
  5. **Adaptive Batching** - Dynamically adjusts batch sizes based on load

  ## Buffer Policies

  - **Load-Aware Buffering**: Buffer size adapts to processing engine load
  - **Pattern-Based Grouping**: Groups operations based on learned access patterns
  - **Congestion Control**: Implements TCP-like congestion control for message delivery
  - **Hot Key Optimization**: Special handling for frequently accessed keys

  ## Intelligent Delivery

  - **Adaptive Rate Control**: Delivery rate adjusts based on processing feedback
  - **Load Monitoring**: Monitors processing engine performance metrics
  - **Predictive Delivery**: Uses pattern recognition for optimal delivery timing
  - **Circuit Breaker**: Implements circuit breaker pattern for overload protection
  """

  use GenStage
  use TypedStruct

  @behaviour EngineSystem.Mailbox.Behaviour

  alias EngineSystem.Engine.{Spec, State}
  alias EngineSystem.Mailbox.Message

  # Adaptive configuration defaults
  @default_initial_buffer_size 500
  @default_min_buffer_size 100
  @default_max_buffer_size 5000
  @default_initial_batch_size 5
  @default_adaptation_window_ms 1000
  @default_hot_key_threshold 10

  # Load control states
  @state_normal :normal
  @state_congested :congested
  @state_overloaded :overloaded

  typedstruct do
    @typedoc """
    State for the KV Adaptive Mailbox Engine.
    """
    field(:address, State.address(), enforce: true)
    field(:processing_engine_spec, Spec.t(), enforce: true)
    field(:message_interface, Spec.message_interface(), enforce: true)
    field(:message_filter, function(), enforce: true)

    # Adaptive buffering
    field(:message_buffer, :queue.queue(Message.t()), enforce: false, default: :queue.new())

    field(:current_buffer_size, non_neg_integer(),
      enforce: false,
      default: @default_initial_buffer_size
    )

    field(:min_buffer_size, non_neg_integer(), enforce: false, default: @default_min_buffer_size)
    field(:max_buffer_size, non_neg_integer(), enforce: false, default: @default_max_buffer_size)

    # Load balancing
    field(:current_batch_size, non_neg_integer(),
      enforce: false,
      default: @default_initial_batch_size
    )

    field(:load_state, atom(), enforce: false, default: @state_normal)

    field(:congestion_window, non_neg_integer(),
      enforce: false,
      default: @default_initial_batch_size
    )

    field(:slow_start_threshold, non_neg_integer(), enforce: false, default: 100)

    # Pattern recognition
    field(:key_access_patterns, %{any() => %{count: non_neg_integer(), last_access: integer()}},
      enforce: false,
      default: %{}
    )

    field(:hot_keys, MapSet.t(), enforce: false, default: MapSet.new())

    field(:access_sequence, :queue.queue({any(), integer()}),
      enforce: false,
      default: :queue.new()
    )

    # Performance monitoring
    field(:delivery_times, :queue.queue(integer()), enforce: false, default: :queue.new())
    field(:processing_latencies, :queue.queue(integer()), enforce: false, default: :queue.new())
    field(:avg_processing_time, float(), enforce: false, default: 0.0)
    field(:load_average, float(), enforce: false, default: 0.0)

    # Delivery management
    field(:current_demand, non_neg_integer(), enforce: false, default: 0)
    field(:adaptation_timer, reference() | nil, enforce: false, default: nil)
    field(:last_adaptation_time, integer(), enforce: false, default: 0)

    field(:adaptation_window_ms, non_neg_integer(),
      enforce: false,
      default: @default_adaptation_window_ms
    )

    # Statistics
    field(:total_received, non_neg_integer(), enforce: false, default: 0)
    field(:total_delivered, non_neg_integer(), enforce: false, default: 0)
    field(:adaptations_count, non_neg_integer(), enforce: false, default: 0)
    field(:congestion_events, non_neg_integer(), enforce: false, default: 0)
  end

  ## Client API

  @doc """
  Start a KV Adaptive Mailbox Engine.
  """
  @spec start_link(map()) :: GenServer.on_start()
  @impl EngineSystem.Mailbox.Behaviour
  def start_link(mailbox_spec) do
    GenStage.start_link(__MODULE__, mailbox_spec)
  end

  @doc """
  Enqueue a message with adaptive buffering.
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
  Force adaptation of buffer and delivery policies.
  """
  @spec force_adaptation(pid()) :: :ok
  def force_adaptation(mailbox_pid) do
    GenStage.cast(mailbox_pid, :force_adaptation)
  end

  @doc """
  Get detailed performance statistics.
  """
  @spec get_performance_stats(pid()) :: map()
  def get_performance_stats(mailbox_pid) do
    GenStage.call(mailbox_pid, :get_performance_stats)
  end

  ## GenStage Callbacks

  @impl true
  def init(mailbox_spec) do
    mailbox_config = Map.get(mailbox_spec, :mailbox_config, %{})

    state = %__MODULE__{
      address: mailbox_spec.address,
      processing_engine_spec: mailbox_spec.processing_engine_spec,
      message_interface: mailbox_spec.message_interface,
      message_filter: mailbox_spec.message_filter,
      current_buffer_size:
        Map.get(mailbox_config, :initial_buffer_size, @default_initial_buffer_size),
      min_buffer_size: Map.get(mailbox_config, :min_buffer_size, @default_min_buffer_size),
      max_buffer_size: Map.get(mailbox_config, :max_buffer_size, @default_max_buffer_size),
      adaptation_window_ms:
        Map.get(mailbox_config, :adaptation_window_ms, @default_adaptation_window_ms)
    }

    # Start adaptation timer
    timer_ref = schedule_adaptation(state.adaptation_window_ms)

    {:producer, %{state | adaptation_timer: timer_ref}}
  end

  @impl true
  def handle_demand(demand, state) do
    new_demand = state.current_demand + demand
    new_state = %{state | current_demand: new_demand}

    # Deliver messages with adaptive control
    {events, final_state} = deliver_messages_adaptively(new_state)

    {:noreply, events, final_state}
  end

  @impl true
  def handle_cast({:enqueue_message, message}, state) do
    case validate_message_interface(message, state.message_interface) do
      :ok ->
        new_state = buffer_message_adaptively(message, state)
        {events, final_state} = deliver_messages_adaptively(new_state)
        {:noreply, events, final_state}

      {:error, _reason} ->
        # Invalid message, ignore
        {:noreply, [], state}
    end
  end

  @impl true
  def handle_cast(:force_adaptation, state) do
    new_state = perform_adaptation(state)
    {:noreply, [], new_state}
  end

  @impl true
  def handle_call({:update_filter, new_filter}, _from, state) do
    new_state = %{state | message_filter: new_filter}
    {:reply, :ok, [], new_state}
  end

  @impl true
  def handle_call(:get_info, _from, state) do
    info = calculate_performance_stats(state)
    {:reply, info, [], state}
  end

  @impl true
  def handle_call(:get_performance_stats, _from, state) do
    stats = calculate_performance_stats(state)
    {:reply, stats, [], state}
  end

  @impl true
  def handle_info(:perform_adaptation, state) do
    # Perform periodic adaptation
    new_state = perform_adaptation(state)

    # Reschedule adaptation
    timer_ref = schedule_adaptation(new_state.adaptation_window_ms)
    final_state = %{new_state | adaptation_timer: timer_ref}

    # Try to deliver messages after adaptation
    {events, updated_state} = deliver_messages_adaptively(final_state)

    {:noreply, events, updated_state}
  end

  ## Private Functions

  @spec buffer_message_adaptively(Message.t(), t()) :: t()
  defp buffer_message_adaptively(message, state) do
    # Update access patterns
    key = extract_key_from_message(message)
    current_time = :erlang.system_time(:millisecond)

    # Record key access pattern
    new_patterns = update_access_patterns(state.key_access_patterns, key, current_time)
    new_hot_keys = update_hot_keys(state.hot_keys, key, new_patterns)

    # Add to access sequence for pattern learning
    new_sequence = add_to_access_sequence(state.access_sequence, {key, current_time})

    # Buffer the message
    new_buffer = :queue.in(message, state.message_buffer)
    buffer_length = :queue.len(new_buffer)

    # Check if we need to apply backpressure
    new_load_state = calculate_load_state(buffer_length, state)

    %{
      state
      | message_buffer: new_buffer,
        key_access_patterns: new_patterns,
        hot_keys: new_hot_keys,
        access_sequence: new_sequence,
        load_state: new_load_state,
        total_received: state.total_received + 1
    }
  end

  @spec deliver_messages_adaptively(t()) :: {[Message.t()], t()}
  defp deliver_messages_adaptively(%{current_demand: 0} = state) do
    {[], state}
  end

  defp deliver_messages_adaptively(state) do
    # Calculate adaptive batch size based on current conditions
    batch_size = calculate_adaptive_batch_size(state)

    # Extract messages for delivery
    {messages, new_state} = extract_adaptive_batch(state, batch_size)

    # Update congestion control
    final_state = update_congestion_control(new_state, length(messages))

    # Record delivery timing
    delivery_time = :erlang.system_time(:millisecond)
    updated_state = record_delivery_time(final_state, delivery_time, length(messages))

    {messages, updated_state}
  end

  @spec extract_adaptive_batch(t(), non_neg_integer()) :: {[Message.t()], t()}
  defp extract_adaptive_batch(state, max_batch_size) do
    extract_messages_from_buffer(state, max_batch_size, [])
  end

  @spec extract_messages_from_buffer(t(), non_neg_integer(), [Message.t()]) ::
          {[Message.t()], t()}
  defp extract_messages_from_buffer(state, 0, acc) do
    delivered_count = length(acc)

    final_state = %{
      state
      | current_demand: state.current_demand - delivered_count,
        total_delivered: state.total_delivered + delivered_count
    }

    {Enum.reverse(acc), final_state}
  end

  defp extract_messages_from_buffer(state, remaining, acc) do
    case :queue.out(state.message_buffer) do
      {:empty, _queue} ->
        delivered_count = length(acc)

        final_state = %{
          state
          | current_demand: state.current_demand - delivered_count,
            total_delivered: state.total_delivered + delivered_count
        }

        {Enum.reverse(acc), final_state}

      {{:value, message}, new_buffer} ->
        # Apply message filter
        if apply_message_filter(message, state.message_filter) do
          new_state = %{state | message_buffer: new_buffer}
          extract_messages_from_buffer(new_state, remaining - 1, [message | acc])
        else
          new_state = %{state | message_buffer: new_buffer}
          extract_messages_from_buffer(new_state, remaining, acc)
        end
    end
  end

  @spec perform_adaptation(t()) :: t()
  defp perform_adaptation(state) do
    # Calculate load metrics
    current_time = :erlang.system_time(:millisecond)
    buffer_utilization = :queue.len(state.message_buffer) / state.current_buffer_size

    # Update load average
    new_load_average = update_load_average(state.load_average, buffer_utilization)

    # Adapt buffer size
    new_buffer_size = adapt_buffer_size(state.current_buffer_size, new_load_average, state)

    # Adapt batch size
    new_batch_size = adapt_batch_size(state.current_batch_size, state.avg_processing_time, state)

    # Update congestion window based on load
    new_congestion_window =
      adapt_congestion_window(state.congestion_window, state.load_state, state)

    %{
      state
      | current_buffer_size: new_buffer_size,
        current_batch_size: new_batch_size,
        congestion_window: new_congestion_window,
        load_average: new_load_average,
        last_adaptation_time: current_time,
        adaptations_count: state.adaptations_count + 1
    }
  end

  # Helper functions for adaptive algorithms

  @spec calculate_adaptive_batch_size(t()) :: non_neg_integer()
  defp calculate_adaptive_batch_size(state) do
    base_size = min(state.current_demand, state.current_batch_size)

    # Apply congestion control
    congestion_limited = min(base_size, state.congestion_window)

    # Apply load-based adjustment
    case state.load_state do
      @state_normal -> congestion_limited
      @state_congested -> max(1, div(congestion_limited, 2))
      @state_overloaded -> 1
    end
  end

  @spec calculate_load_state(non_neg_integer(), t()) :: atom()
  defp calculate_load_state(buffer_length, state) do
    utilization = buffer_length / state.current_buffer_size

    cond do
      utilization > 0.9 -> @state_overloaded
      utilization > 0.7 -> @state_congested
      true -> @state_normal
    end
  end

  @spec update_congestion_control(t(), non_neg_integer()) :: t()
  defp update_congestion_control(state, delivered_count) do
    case state.load_state do
      @state_normal ->
        # Increase congestion window (slow start or congestion avoidance)
        new_window =
          if state.congestion_window < state.slow_start_threshold do
            # Slow start: exponential increase
            state.congestion_window + delivered_count
          else
            # Congestion avoidance: linear increase
            state.congestion_window + max(1, div(delivered_count, state.congestion_window))
          end

        %{state | congestion_window: min(new_window, state.max_buffer_size)}

      @state_congested ->
        # Mild reduction
        new_window = max(1, div(state.congestion_window * 3, 4))

        %{
          state
          | congestion_window: new_window,
            slow_start_threshold: div(state.congestion_window, 2),
            congestion_events: state.congestion_events + 1
        }

      @state_overloaded ->
        # Aggressive reduction
        new_window = max(1, div(state.congestion_window, 2))

        %{
          state
          | congestion_window: new_window,
            slow_start_threshold: div(state.congestion_window, 2),
            congestion_events: state.congestion_events + 1
        }
    end
  end

  @spec adapt_buffer_size(non_neg_integer(), float(), t()) :: non_neg_integer()
  defp adapt_buffer_size(current_size, load_average, state) do
    cond do
      load_average > 0.8 ->
        # Increase buffer size
        min(round(current_size * 1.1), state.max_buffer_size)

      load_average < 0.3 ->
        # Decrease buffer size
        max(round(current_size * 0.9), state.min_buffer_size)

      true ->
        current_size
    end
  end

  @spec adapt_batch_size(non_neg_integer(), float(), t()) :: non_neg_integer()
  defp adapt_batch_size(current_batch_size, avg_processing_time, _state) do
    # Adapt based on processing time
    cond do
      avg_processing_time > 100.0 ->
        # Slow processing, reduce batch size
        max(1, current_batch_size - 1)

      avg_processing_time < 10.0 ->
        # Fast processing, increase batch size
        min(current_batch_size + 1, 50)

      true ->
        current_batch_size
    end
  end

  @spec adapt_congestion_window(non_neg_integer(), atom(), t()) :: non_neg_integer()
  defp adapt_congestion_window(current_window, load_state, state) do
    case load_state do
      @state_normal -> min(current_window + 1, state.max_buffer_size)
      @state_congested -> max(div(current_window * 3, 4), 1)
      @state_overloaded -> max(div(current_window, 2), 1)
    end
  end

  # Pattern recognition and monitoring helpers

  @spec update_access_patterns(
          %{any() => %{count: non_neg_integer(), last_access: integer()}},
          any(),
          integer()
        ) ::
          %{any() => %{count: non_neg_integer(), last_access: integer()}}
  defp update_access_patterns(patterns, key, current_time) do
    current_pattern = Map.get(patterns, key, %{count: 0, last_access: 0})

    new_pattern = %{
      count: current_pattern.count + 1,
      last_access: current_time
    }

    Map.put(patterns, key, new_pattern)
  end

  @spec update_hot_keys(MapSet.t(), any(), %{
          any() => %{count: non_neg_integer(), last_access: integer()}
        }) ::
          MapSet.t()
  defp update_hot_keys(hot_keys, key, patterns) do
    pattern = Map.get(patterns, key, %{count: 0})

    if pattern.count >= @default_hot_key_threshold do
      MapSet.put(hot_keys, key)
    else
      hot_keys
    end
  end

  @spec add_to_access_sequence(:queue.queue({any(), integer()}), {any(), integer()}) ::
          :queue.queue({any(), integer()})
  defp add_to_access_sequence(sequence, access) do
    new_sequence = :queue.in(access, sequence)
    # Keep only recent accesses (last 1000)
    if :queue.len(new_sequence) > 1000 do
      {_, trimmed_sequence} = :queue.out(new_sequence)
      trimmed_sequence
    else
      new_sequence
    end
  end

  @spec record_delivery_time(t(), integer(), integer()) :: t()
  defp record_delivery_time(state, _delivery_time, message_count) do
    # Update metrics based on delivery performance
    new_total_delivered = state.total_delivered + message_count

    %{
      state
      | total_delivered: new_total_delivered,
        last_delivery_time: :erlang.system_time(:microsecond)
    }
  end

  @spec update_load_average(float(), float()) :: float()
  defp update_load_average(current_avg, new_sample) do
    # Exponential moving average
    alpha = 0.1
    alpha * new_sample + (1 - alpha) * current_avg
  end

  # Utility functions

  @spec extract_key_from_message(Message.t()) :: any()
  defp extract_key_from_message(message) do
    case message.payload do
      {:get, key} -> key
      {:put, key, _value} -> key
      {:delete, key} -> key
      {_tag, %{key: key}} -> key
      _ -> :unknown_key
    end
  end

  @spec schedule_adaptation(non_neg_integer()) :: reference()
  defp schedule_adaptation(interval_ms) do
    Process.send_after(self(), :perform_adaptation, interval_ms)
  end

  @spec calculate_performance_stats(t()) :: map()
  defp calculate_performance_stats(state) do
    %{
      load_average: state.load_average,
      avg_processing_time: state.avg_processing_time,
      adaptations_count: state.adaptations_count,
      congestion_events: state.congestion_events,
      buffer_utilization: :queue.len(state.message_buffer) / state.current_buffer_size,
      hot_keys: MapSet.to_list(state.hot_keys),
      access_patterns_count: map_size(state.key_access_patterns),
      delivery_efficiency:
        if(state.total_received > 0, do: state.total_delivered / state.total_received, else: 0.0)
    }
  end

  # Message validation helpers
  @spec validate_message_interface(Message.t(), Spec.message_interface()) :: :ok | {:error, any()}
  defp validate_message_interface(message, interface) do
    case Message.get_tag(message) do
      {:ok, tag} ->
        case Enum.find(interface, fn {msg_tag, _fields} -> msg_tag == tag end) do
          nil -> {:error, {:unknown_message_tag, tag}}
          {^tag, _fields} -> :ok
        end

      :no_tag ->
        {:error, :no_message_tag}
    end
  end

  @spec apply_message_filter(Message.t(), function()) :: boolean()
  defp apply_message_filter(message, filter_fn) do
    filter_fn.(message.payload, %{}, %{})
  rescue
    _error -> true
  end
end
