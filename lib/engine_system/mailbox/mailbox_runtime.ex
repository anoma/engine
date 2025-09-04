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

    # Create a properly formatted :request_batch message for DSL behaviour
    # The DSL expects: on_message :request_batch, %{demand: demand}, ...
    dsl_message = Message.new(nil, state.address, {:request_batch, %{demand: demand}})

    case execute_behaviour(dsl_message, new_state) do
      {:ok, effects, updated_state} ->
        # Process immediate effects first
        final_state = process_immediate_effects(effects, updated_state)
        events = extract_events_from_effects(effects)
        {:noreply, events, final_state}

      {:error, _reason} ->
        {:noreply, [], new_state}
    end
  end

  @impl true
  def handle_cast({:enqueue_message, message}, state) do
    IO.puts("🔧 MailboxRuntime #{inspect(message.target)}: Received enqueue_message cast")
    IO.puts("🔧 MailboxRuntime #{inspect(message.target)}: Message from: #{inspect(message.sender)}")
    IO.puts("🔧 MailboxRuntime #{inspect(message.target)}: Message payload: #{inspect(message.payload)}")

    # Check if this is an internal mailbox message that should be routed directly
    internal_mailbox_messages = [
      :check_dispatch,
      :request_batch,
      :update_filter,
      :pe_down,
      :pe_ready
    ]

    message_tag =
      case message.payload do
        {tag, _} -> tag
        tag when is_atom(tag) -> tag
        _ -> nil
      end

    is_internal_message = message_tag in internal_mailbox_messages

    if is_internal_message do
      # Route internal messages directly to their handlers
      IO.puts(
        "🔧 MailboxRuntime #{inspect(message.target)}: Routing internal message #{inspect(message_tag)} directly to handler"
      )

      dsl_message = Message.new(nil, state.address, message.payload)

      case execute_behaviour(dsl_message, state) do
        {:ok, effects, updated_state} ->
          IO.puts(
            "🔧 MailboxRuntime #{inspect(message.target)}: Internal message behavior executed successfully, effects: #{inspect(effects)}"
          )

          # Process immediate effects first
          final_state = process_immediate_effects(effects, updated_state)
          events = extract_events_from_effects(effects)
          IO.puts("🔧 MailboxRuntime #{inspect(message.target)}: Extracted events: #{inspect(events)}")
          {:noreply, events, final_state}

        {:error, reason} ->
          IO.puts(
            "🔧 MailboxRuntime #{inspect(message.target)}: Internal message behavior execution failed: #{inspect(reason)}"
          )

          {:noreply, [], state}
      end
    else
      # External messages go through the normal :enqueue_message flow
      IO.puts("🔧 MailboxRuntime #{inspect(message.target)}: Processing external message through :enqueue_message handler")
      # Create a properly formatted :enqueue_message message for DSL behaviour
      # The DSL expects: on_message :enqueue_message, %{message: message}, ...
      dsl_message = Message.new(nil, state.address, {:enqueue_message, %{message: message}})
      IO.puts("🔧 MailboxRuntime #{inspect(message.target)}: Created DSL message: #{inspect(dsl_message.payload)}")

      case execute_behaviour(dsl_message, state) do
        {:ok, effects, updated_state} ->
          IO.puts(
            "🔧 MailboxRuntime #{inspect(message.target)}: Behavior executed successfully, effects: #{inspect(effects)}"
          )

          # Process immediate effects first
          final_state = process_immediate_effects(effects, updated_state)
          events = extract_events_from_effects(effects)
          IO.puts("🔧 MailboxRuntime #{inspect(message.target)}: Extracted events: #{inspect(events)}")
          {:noreply, events, final_state}

        {:error, reason} ->
          IO.puts("🔧 MailboxRuntime #{inspect(message.target)}: Behavior execution failed: #{inspect(reason)}")
          {:noreply, [], state}
      end
    end
  end

  @impl true
  def handle_call({:update_filter, new_filter}, _from, state) do
    # Create a properly formatted :update_filter message for DSL behaviour
    # The DSL expects: on_message :update_filter, %{filter: filter}, ...
    dsl_message = Message.new(nil, state.address, {:update_filter, %{filter: new_filter}})

    case execute_behaviour(dsl_message, state) do
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

  @impl true
  def handle_call({:update_pe_address, pe_address}, _from, state) do
    # Update the environment with the processing engine address
    new_env = Map.put(state.environment, :pe_address, pe_address)
    new_state = %{state | environment: new_env}
    {:reply, :ok, [], new_state}
  end

  @impl true
  def handle_call({:update_pe_info, pe_address, engine_pid}, _from, state) do
    # Update the environment with the processing engine address and PID
    # This establishes the proper parent-child relationship
    new_env =
      Map.merge(state.environment, %{
        pe_address: pe_address,
        pe_pid: engine_pid
      })

    # Update the configuration to include the processing engine as parent
    new_config = Map.put(state.configuration, :parent, engine_pid)

    new_state = %{state | environment: new_env, configuration: new_config}
    {:reply, :ok, [], new_state}
  end

  ## Private Functions

  # Execute DSL-defined behaviour patterns
  defp execute_behaviour(message, state) do
    # Create proper State.Configuration and State.Environment structures
    # The behavior evaluation expects these to have local_state fields
    config_struct =
      State.Configuration.new(
        Map.get(state.configuration, :parent),
        Map.get(state.configuration, :mode, :mailbox),
        state.configuration
      )

    env_struct = State.Environment.new(state.environment, %{})

    case Behaviour.evaluate(state.spec, message, config_struct, env_struct) do
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
  # Handle self-sends differently
  defp effect_to_events({:send, :self, _message}), do: []
  defp effect_to_events({:send, _target, message}), do: [message]
  defp effect_to_events(_), do: []

  # Process effects that need immediate handling (like self-sends)
  defp process_immediate_effects(effects, state) do
    Enum.reduce(effects, state, fn effect, current_state ->
      case effect do
        {:send, :self, message_payload} ->
          # Send message to self asynchronously
          dsl_message = Message.new(nil, current_state.address, message_payload)
          GenStage.cast(self(), {:enqueue_message, dsl_message})
          current_state

        _ ->
          current_state
      end
    end)
  end
end
