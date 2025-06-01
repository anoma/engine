defmodule EngineSystem.Engine.Instance do
  @moduledoc """
  Processing engine implementing the s-Process rule from the formal paper.

  This GenStage consumer processes messages following Def. 3.5 from
  "ART-Mailboxes-actors/main.tex", executing guarded actions and effects.

  ## Paper References

  - **Def. 3.5 (s-Process)**: Core message processing rule
  - **Def. 2.15 (Engine)**: Engine structure and components
  - **Section 3.3**: Behaviour evaluation rules (b-GuardedActionEval, b-GuardStrategy)
  - **Section 3.4**: Effect execution rules (e-Send, e-Update, etc.)
  - **Def. 2.5**: Engine lifecycle (ready ⟷ busy → terminated)

  ## Processing Flow

  Following the s-Process rule semantics:
  1. Receive message from mailbox (m-Dequeue)
  2. Transition to busy state with message
  3. Evaluate behaviour using guarded actions
  4. Execute resulting effects
  5. Return to ready state

  This implements the core processing logic for engines in the mailbox-as-actors pattern,
  where processing engines focus solely on business logic while mailbox engines handle
  message management.
  """

  use GenStage
  use TypedStruct

  alias EngineSystem.Engine.{Behaviour, Effect, Spec, State}
  alias EngineSystem.System.Message

  typedstruct do
    @typedoc """
    I define the structure for a processing engine instance.

    ### Fields

    - `:address` - The engine's address. Enforced: true.
    - `:spec` - The engine specification. Enforced: true.
    - `:configuration` - The engine configuration. Enforced: true.
    - `:environment` - The engine environment. Enforced: true.
    - `:status` - The engine status. Enforced: true.
    - `:mailbox_pid` - The associated mailbox PID. Enforced: true.
    """
    field(:address, State.address(), enforce: true)
    field(:spec, Spec.t(), enforce: true)
    field(:configuration, State.Configuration.t(), enforce: true)
    field(:environment, State.Environment.t(), enforce: true)
    field(:status, State.Status.t(), enforce: true)
    field(:mailbox_pid, pid(), enforce: true)
  end

  ## Client API

  @doc """
  I start an engine instance GenServer.

  ## Parameters

  - `init_data` - Map containing initialization data:
    - `:address` - The engine's address
    - `:spec` - The engine specification
    - `:configuration` - The engine configuration
    - `:environment` - The engine environment
    - `:status` - The initial status
    - `:mailbox_pid` - The associated mailbox PID

  ## Returns

  GenServer start result.
  """
  @spec start_link(map()) :: GenServer.on_start()
  def start_link(init_data) do
    GenStage.start_link(__MODULE__, init_data)
  end

  @doc """
  I get the current state of the engine.

  ## Parameters

  - `pid` - The engine instance PID

  ## Returns

  The current engine state.
  """
  @spec get_state(pid()) :: t()
  def get_state(pid) do
    GenStage.call(pid, :get_state)
  end

  @doc """
  I update the engine's message filter.

  ## Parameters

  - `pid` - The engine instance PID
  - `new_filter` - The new message filter function

  ## Returns

  `:ok` if the filter was updated successfully.
  """
  @spec update_message_filter(pid(), function()) :: :ok
  def update_message_filter(pid, new_filter) do
    GenStage.call(pid, {:update_message_filter, new_filter})
  end

  @doc """
  I terminate the engine instance.

  ## Parameters

  - `pid` - The engine instance PID

  ## Returns

  `:ok` if termination was initiated successfully.
  """
  @spec terminate_engine(pid()) :: :ok
  def terminate_engine(pid) do
    GenStage.call(pid, :terminate)
  end

  ## GenStage Callbacks

  @impl true
  def init(init_data) do
    state = %__MODULE__{
      address: init_data.address,
      spec: init_data.spec,
      configuration: init_data.configuration,
      environment: init_data.environment,
      status: init_data.status,
      mailbox_pid: init_data.mailbox_pid
    }

    # Subscribe to the mailbox as a consumer
    # Configure to fetch one message at a time to maintain actor semantics
    subscription_options = [
      max_demand: 1,
      min_demand: 0
    ]

    {:consumer, state, subscribe_to: [{state.mailbox_pid, subscription_options}]}
  end

  @impl true
  def handle_events(events, _from, state) do
    # Process events one by one to maintain single active message semantics
    new_state = Enum.reduce(events, state, &process_message/2)
    {:noreply, [], new_state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, [], state}
  end

  @impl true
  def handle_call({:update_message_filter, new_filter}, _from, state) do
    # Update our status with the new filter
    new_status = State.Status.ready(new_filter)
    new_state = %{state | status: new_status}

    # Notify the mailbox of the filter change
    if state.mailbox_pid do
      GenStage.call(state.mailbox_pid, {:update_filter, new_filter})
    end

    {:reply, :ok, [], new_state}
  end

  @impl true
  def handle_call(:terminate, _from, state) do
    new_status = State.Status.terminated()
    new_state = %{state | status: new_status}
    {:stop, :normal, :ok, new_state}
  end

  ## Private Functions

  @spec process_message(Message.t(), t()) :: t()
  defp process_message(message, state) do
    # Transition to busy state
    busy_status = State.Status.busy(message)
    busy_state = %{state | status: busy_status}

    with {:ok, effects} <-
           Behaviour.evaluate(
             busy_state.spec,
             message,
             busy_state.configuration,
             busy_state.environment
           ),
         {:ok, updated_state} <- execute_effects(effects, busy_state) do
      # Return to ready state with current filter
      return_to_ready_state(updated_state, state)
    else
      {:error, _reason} ->
        # On error, return to ready state
        return_to_ready_state(busy_state, state)
    end
  end

  defp return_to_ready_state(current_state, original_state) do
    case State.Status.get_filter(original_state.status) do
      {:ok, filter} ->
        ready_status = State.Status.ready(filter)
        %{current_state | status: ready_status}

      :not_ready ->
        # Use default filter if we can't get the previous one
        default_filter = fn _msg, _config, _env -> true end
        ready_status = State.Status.ready(default_filter)
        %{current_state | status: ready_status}
    end
  end

  @spec execute_effects([Effect.t()], t()) :: {:ok, t()} | {:error, any()}
  defp execute_effects(effects, state) do
    # Execute effects sequentially
    Enum.reduce_while(effects, {:ok, state}, fn effect, {:ok, current_state} ->
      case Effect.execute(effect, current_state) do
        {:ok, updated_state} -> {:cont, {:ok, updated_state}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    if pid == state.mailbox_pid do
      # Our mailbox died, we should probably terminate too
      {:stop, :mailbox_died, state}
    else
      {:noreply, [], state}
    end
  end

  @impl true
  def handle_info(_msg, state) do
    # Ignore unknown messages
    {:noreply, [], state}
  end

  @impl true
  def terminate(_reason, _state) do
    :ok
  end
end
