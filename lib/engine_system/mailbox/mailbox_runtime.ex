defmodule EngineSystem.Mailbox.MailboxRuntime do
  @moduledoc """
  I am the core runtime GenStage producer implementation for DSL-defined mailbox engines.

  This module provides the bridge between the DSL-defined mailbox behaviors and
  actual GenStage producer functionality. When you define an engine with `mode :mailbox`,
  this module provides the runtime execution environment.

  ## Core Functions

  - Implements GenStage Producer callbacks (`handle_demand`, `handle_cast`, etc.)
  - Executes DSL-defined behaviors for mailbox operations
  - Manages the producer-consumer pattern for message delivery
  - Provides the actual `handle_demand` implementation

  """

  use GenStage
  use TypedStruct

  alias EngineSystem.Engine.{Behaviour, Spec, State}
  alias EngineSystem.System.Message

  @behaviour EngineSystem.Mailbox.Behaviour

  typedstruct do
    @typedoc """
    Runtime state for a DSL-defined mailbox engine.
    """
    field(:address, State.address(), enforce: true)
    field(:spec, Spec.t(), enforce: true)
    field(:configuration, any(), enforce: true)
    field(:environment, any(), enforce: true)
    field(:current_demand, non_neg_integer(), default: 0)
  end

  ## Client API (implementing Mailbox.Behaviour)

  @spec start_link(map()) :: GenServer.on_start()
  @impl EngineSystem.Mailbox.Behaviour
  def start_link(mailbox_spec) do
    GenStage.start_link(__MODULE__, mailbox_spec)
  end

  @spec enqueue_message(pid(), Message.t()) :: :ok
  @impl EngineSystem.Mailbox.Behaviour
  def enqueue_message(mailbox_pid, message) do
    GenStage.cast(mailbox_pid, {:enqueue_message, message})
  end

  @spec update_filter(pid(), function()) :: :ok
  @impl EngineSystem.Mailbox.Behaviour
  def update_filter(mailbox_pid, new_filter) do
    GenStage.call(mailbox_pid, {:update_filter, new_filter})
  end

  @spec get_info(pid()) :: map()
  @impl EngineSystem.Mailbox.Behaviour
  def get_info(mailbox_pid) do
    GenStage.call(mailbox_pid, :get_info)
  end

  ## GenStage Callbacks

  @impl true
  def init(mailbox_spec) do
    # Extract the mailbox engine spec
    spec = mailbox_spec.spec || mailbox_spec.engine_module.__engine_spec__()

    # Initialize state with default config and environment
    default_config = spec.config_spec.default || %{}
    default_env = spec.env_spec.default || %{}

    state = %__MODULE__{
      address: mailbox_spec.address,
      spec: spec,
      configuration: Map.merge(default_config, Map.get(mailbox_spec, :configuration, %{})),
      environment: Map.merge(default_env, Map.get(mailbox_spec, :environment, %{})),
      current_demand: 0
    }

    {:producer, state}
  end

  @impl true
  def handle_demand(demand, state) do
    # Update current demand
    new_demand = state.current_demand + demand
    new_state = %{state | current_demand: new_demand}

    # Create a :request_batch message and process it through DSL behaviour
    message = Message.new(:request_batch, %{demand: demand}, state.address)

    case execute_behaviour(message, new_state) do
      {:ok, effects, updated_state} ->
        events = extract_events_from_effects(effects)
        {:noreply, events, updated_state}

      {:error, _reason} ->
        {:noreply, [], new_state}
    end
  end

  @impl true
  def handle_cast({:enqueue_message, message}, state) do
    # Process enqueue_message through DSL behaviour
    case execute_behaviour(message, state) do
      {:ok, effects, updated_state} ->
        events = extract_events_from_effects(effects)
        {:noreply, events, updated_state}

      {:error, _reason} ->
        {:noreply, [], state}
    end
  end

  @impl true
  def handle_call({:update_filter, new_filter}, _from, state) do
    # Create an :update_filter message and process it through DSL behaviour
    message = Message.new(:update_filter, %{filter: new_filter}, state.address)

    case execute_behaviour(message, state) do
      {:ok, _effects, updated_state} ->
        {:reply, :ok, [], updated_state}

      {:error, _reason} ->
        {:reply, :ok, [], state}
    end
  end

  @impl true
  def handle_call(:get_info, _from, state) do
    info = %{
      address: state.address,
      current_demand: state.current_demand,
      environment: state.environment,
      configuration: state.configuration,
      spec: state.spec
    }
    {:reply, info, [], state}
  end

  ## Private Functions

  # Execute DSL-defined behaviour patterns
  defp execute_behaviour(message, state) do
    try do
      case Behaviour.evaluate(state.spec, message, state.configuration, state.environment) do
        {:ok, effects} ->
          case apply_effects_to_state(effects, state) do
            {:ok, updated_state} -> {:ok, effects, updated_state}
            {:error, reason} -> {:error, reason}
          end

        {:error, reason} ->
          {:error, reason}
      end
    rescue
      exception -> {:error, {:behaviour_error, exception}}
    end
  end

  # Apply effects to update mailbox state
  defp apply_effects_to_state(effects, state) do
    Enum.reduce(effects, {:ok, state}, fn
      effect, {:ok, current_state} ->
        apply_single_effect(effect, current_state)

      _effect, error ->
        error
    end)
  end

  # Apply individual effect to state
  defp apply_single_effect({:update_environment, new_env}, state) do
    {:ok, %{state | environment: new_env}}
  end

  defp apply_single_effect(_effect, state) do
    # Other effects don't modify mailbox state directly
    {:ok, state}
  end

  # Extract GenStage events from effects
  defp extract_events_from_effects(effects) do
    Enum.flat_map(effects, &effect_to_events/1)
  end

  defp effect_to_events({:deliver_batch, messages}), do: messages
  defp effect_to_events({:send, _target, message}), do: [message]
  defp effect_to_events(_), do: []
end
