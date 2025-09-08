defmodule EngineSystem.Engine.RuntimeFlowTracker do
  @moduledoc """
  I track runtime message flows and communication patterns for diagram refinement.

  This module collects telemetry data about actual message flows during system
  execution, which can be used to refine compile-time generated diagrams with
  real usage patterns.

  ## Features

  - **Message Flow Tracking**: Capture all message routing and delivery
  - **Frequency Analysis**: Track message volumes and patterns
  - **Timing Information**: Collect response times and sequence data
  - **Error Pattern Tracking**: Monitor failed communications
  - **Dynamic Target Resolution**: Track actual targets for dynamic routing

  ## Usage

  ```elixir
  # Start flow tracking
  EngineSystem.Engine.RuntimeFlowTracker.start_tracking()

  # Get runtime flow data
  flows = EngineSystem.Engine.RuntimeFlowTracker.get_flow_data()

  # Generate refined diagram
  DiagramGenerator.generate_runtime_refined_diagram(spec, flows)
  ```
  """

  use GenServer
  use TypedStruct

  alias EngineSystem.Engine.State

  @type flow_event :: %{
    event_type: :message_sent | :message_received | :message_failed,
    source_engine: State.address() | :client,
    target_engine: State.address() | :dynamic | :sender,
    message_type: atom(),
    payload: any(),
    timestamp: integer(),
    duration_ms: non_neg_integer() | nil,
    success: boolean(),
    metadata: map()
  }

  @type flow_summary :: %{
    source_engine: State.address() | :client,
    target_engine: State.address() | :dynamic | :sender,
    message_type: atom(),
    total_count: non_neg_integer(),
    success_count: non_neg_integer(),
    failure_count: non_neg_integer(),
    avg_duration_ms: float() | nil,
    first_seen: integer(),
    last_seen: integer(),
    frequency_per_minute: float()
  }

  typedstruct do
    @typedoc "Runtime state for flow tracking"
    field(:events, [flow_event()], default: [])
    field(:summaries, %{binary() => flow_summary()}, default: %{})
    field(:tracking_enabled, boolean(), default: false)
    field(:start_time, integer(), default: 0)
    field(:max_events, non_neg_integer(), default: 10_000)
  end

  ## Client API

  @doc """
  Start the runtime flow tracker.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Enable runtime flow tracking.
  """
  @spec start_tracking() :: :ok
  def start_tracking do
    GenServer.call(__MODULE__, :start_tracking)
  end

  @doc """
  Disable runtime flow tracking.
  """
  @spec stop_tracking() :: :ok
  def stop_tracking do
    GenServer.call(__MODULE__, :stop_tracking)
  end

  @doc """
  Record a message flow event.
  """
  @spec record_flow_event(flow_event()) :: :ok
  def record_flow_event(event) do
    GenServer.cast(__MODULE__, {:record_event, event})
  end

  @doc """
  Get current flow data summaries.
  """
  @spec get_flow_data() :: [flow_summary()]
  def get_flow_data do
    GenServer.call(__MODULE__, :get_flow_data)
  end

  @doc """
  Get raw flow events.
  """
  @spec get_raw_events() :: [flow_event()]
  def get_raw_events do
    GenServer.call(__MODULE__, :get_raw_events)
  end

  @doc """
  Clear all tracking data.
  """
  @spec clear_data() :: :ok
  def clear_data do
    GenServer.call(__MODULE__, :clear_data)
  end

  @doc """
  Get tracking statistics.
  """
  @spec get_stats() :: map()
  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  ## Telemetry Integration

  @doc """
  Attach telemetry handlers for automatic flow tracking.
  """
  @spec attach_telemetry_handlers() :: :ok
  def attach_telemetry_handlers do
    handlers = [
      {[:engine_system, :message, :sent], &handle_message_sent/4},
      {[:engine_system, :message, :received], &handle_message_received/4},
      {[:engine_system, :message, :failed], &handle_message_failed/4}
    ]

    Enum.each(handlers, fn {event_name, handler} ->
      :telemetry.attach(
        {__MODULE__, event_name},
        event_name,
        handler,
        []
      )
    end)

    :ok
  end

  @doc """
  Detach telemetry handlers.
  """
  @spec detach_telemetry_handlers() :: :ok
  def detach_telemetry_handlers do
    events = [
      [:engine_system, :message, :sent],
      [:engine_system, :message, :received], 
      [:engine_system, :message, :failed]
    ]

    Enum.each(events, fn event_name ->
      :telemetry.detach({__MODULE__, event_name})
    end)

    :ok
  end

  ## GenServer Callbacks

  @impl true
  def init(opts) do
    max_events = Keyword.get(opts, :max_events, 10_000)
    
    state = %__MODULE__{
      max_events: max_events,
      start_time: :erlang.system_time(:millisecond)
    }

    {:ok, state}
  end

  @impl true
  def handle_call(:start_tracking, _from, state) do
    attach_telemetry_handlers()
    new_state = %{state | tracking_enabled: true, start_time: :erlang.system_time(:millisecond)}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:stop_tracking, _from, state) do
    detach_telemetry_handlers()
    new_state = %{state | tracking_enabled: false}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:get_flow_data, _from, state) do
    flows = Map.values(state.summaries)
    {:reply, flows, state}
  end

  @impl true
  def handle_call(:get_raw_events, _from, state) do
    {:reply, state.events, state}
  end

  @impl true
  def handle_call(:clear_data, _from, state) do
    new_state = %{state | 
      events: [],
      summaries: %{},
      start_time: :erlang.system_time(:millisecond)
    }
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    current_time = :erlang.system_time(:millisecond)
    runtime_minutes = (current_time - state.start_time) / (1000 * 60)
    
    events_per_minute = if runtime_minutes > 0, do: length(state.events) / runtime_minutes, else: 0
    
    stats = %{
      tracking_enabled: state.tracking_enabled,
      total_events: length(state.events),
      total_flows: map_size(state.summaries),
      runtime_minutes: runtime_minutes,
      events_per_minute: events_per_minute,
      memory_usage_mb: :erlang.memory(:total) / (1024 * 1024)
    }

    {:reply, stats, state}
  end

  @impl true
  def handle_cast({:record_event, event}, %{tracking_enabled: false} = state) do
    # Ignore events when tracking is disabled
    {:noreply, state}
  end

  @impl true
  def handle_cast({:record_event, event}, state) do
    # Add event to history
    new_events = [event | state.events]
    
    # Trim events if we exceed max_events
    trimmed_events = if length(new_events) > state.max_events do
      Enum.take(new_events, state.max_events)
    else
      new_events
    end

    # Update summary for this flow
    flow_key = generate_flow_key(event)
    updated_summaries = update_flow_summary(state.summaries, flow_key, event)

    new_state = %{state | 
      events: trimmed_events,
      summaries: updated_summaries
    }

    {:noreply, new_state}
  end

  ## Telemetry Handlers

  defp handle_message_sent(_event_name, measurements, metadata, _config) do
    event = %{
      event_type: :message_sent,
      source_engine: Map.get(metadata, :source_engine),
      target_engine: Map.get(metadata, :target_engine),
      message_type: Map.get(metadata, :message_type),
      payload: Map.get(metadata, :payload),
      timestamp: :erlang.system_time(:millisecond),
      duration_ms: Map.get(measurements, :duration),
      success: true,
      metadata: metadata
    }

    record_flow_event(event)
  end

  defp handle_message_received(_event_name, measurements, metadata, _config) do
    event = %{
      event_type: :message_received,
      source_engine: Map.get(metadata, :source_engine),
      target_engine: Map.get(metadata, :target_engine),
      message_type: Map.get(metadata, :message_type),
      payload: Map.get(metadata, :payload),
      timestamp: :erlang.system_time(:millisecond),
      duration_ms: Map.get(measurements, :duration),
      success: true,
      metadata: metadata
    }

    record_flow_event(event)
  end

  defp handle_message_failed(_event_name, measurements, metadata, _config) do
    event = %{
      event_type: :message_failed,
      source_engine: Map.get(metadata, :source_engine),
      target_engine: Map.get(metadata, :target_engine),
      message_type: Map.get(metadata, :message_type),
      payload: Map.get(metadata, :payload),
      timestamp: :erlang.system_time(:millisecond),
      duration_ms: Map.get(measurements, :duration),
      success: false,
      metadata: metadata
    }

    record_flow_event(event)
  end

  ## Private Functions

  defp generate_flow_key(event) do
    "#{inspect(event.source_engine)}_to_#{inspect(event.target_engine)}_#{event.message_type}"
  end

  defp update_flow_summary(summaries, flow_key, event) do
    current_time = :erlang.system_time(:millisecond)
    
    case Map.get(summaries, flow_key) do
      nil ->
        # First occurrence of this flow
        summary = %{
          source_engine: event.source_engine,
          target_engine: event.target_engine,
          message_type: event.message_type,
          total_count: 1,
          success_count: if(event.success, do: 1, else: 0),
          failure_count: if(event.success, do: 0, else: 1),
          avg_duration_ms: event.duration_ms,
          first_seen: current_time,
          last_seen: current_time,
          frequency_per_minute: 0.0
        }
        Map.put(summaries, flow_key, summary)

      existing_summary ->
        # Update existing summary
        new_total = existing_summary.total_count + 1
        new_successes = existing_summary.success_count + if(event.success, do: 1, else: 0)
        new_failures = existing_summary.failure_count + if(event.success, do: 0, else: 1)
        
        # Update average duration
        new_avg_duration = if event.duration_ms do
          if existing_summary.avg_duration_ms do
            (existing_summary.avg_duration_ms * existing_summary.total_count + event.duration_ms) / new_total
          else
            event.duration_ms
          end
        else
          existing_summary.avg_duration_ms
        end

        # Calculate frequency per minute
        time_span_minutes = (current_time - existing_summary.first_seen) / (1000 * 60)
        frequency_per_minute = if time_span_minutes > 0, do: new_total / time_span_minutes, else: 0.0

        updated_summary = %{existing_summary |
          total_count: new_total,
          success_count: new_successes,
          failure_count: new_failures,
          avg_duration_ms: new_avg_duration,
          last_seen: current_time,
          frequency_per_minute: frequency_per_minute
        }
        
        Map.put(summaries, flow_key, updated_summary)
    end
  end
end