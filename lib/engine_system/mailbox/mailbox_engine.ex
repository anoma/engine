defmodule EngineSystem.Mailbox.MailboxEngine do
  @moduledoc """
  I am a mailbox engine implementation following the formal Engine Model.

  According to the paper (Section 3.8), I am a first-class actor that:
  - Intercepts messages sent to processing engines
  - Stores messages using custom policies (FIFO, priority, key-based, etc.)
  - Delivers messages to processing engines when they request them
  - Implements backpressure and flow control

  I use GenStage as a Producer to implement the formal m-Enqueue and m-Dequeue rules.
  """

  use GenStage
  require Logger

  alias EngineSystem.Types.MessageEnvelope
  alias EngineSystem.Mailbox.MessageStore

  # --- Types --- #

  @type engine_address :: {:engine, node(), pos_integer()}
  @type delivery_policy :: :fifo | :priority | :key_based | {module(), any()}
  @type message_store :: MessageStore.t()

  # --- State --- #

  defmodule State do
    @moduledoc false

    @enforce_keys [:processing_engine_address, :message_store, :delivery_policy]

    @type t :: %__MODULE__{
            processing_engine_address: EngineSystem.Mailbox.MailboxEngine.engine_address(),
            message_store: EngineSystem.Mailbox.MailboxEngine.message_store(),
            delivery_policy: EngineSystem.Mailbox.MailboxEngine.delivery_policy(),
            demand: non_neg_integer(),
            parent_ref: reference() | nil,
            total_messages_received: non_neg_integer(),
            total_messages_delivered: non_neg_integer()
          }

    defstruct [
      :processing_engine_address,
      :message_store,
      :delivery_policy,
      demand: 0,
      parent_ref: nil,
      total_messages_received: 0,
      total_messages_delivered: 0
    ]
  end

  # --- Public API --- #

  @doc """
  I start a mailbox engine for a specific processing engine.

  ## Parameters

  - `processing_engine_address` - The address of the processing engine I serve
  - `delivery_policy` - How I should prioritize and deliver messages
  - `opts` - Additional options

  ## Returns

  - `{:ok, pid}` - If I was started successfully
  - `{:error, reason}` - If I could not be started
  """
  @spec start_link(engine_address(), delivery_policy(), keyword()) ::
          {:ok, pid()} | {:error, any()}
  def start_link(processing_engine_address, delivery_policy \\ :fifo, opts \\ []) do
    GenStage.start_link(__MODULE__, {processing_engine_address, delivery_policy}, opts)
  end

  @doc """
  I enqueue a message according to the formal m-Enqueue rule.

  This implements the formal rule from the paper where messages are stored
  in the mailbox engine's local state.

  ## Parameters

  - `mailbox_pid` - My PID
  - `message_envelope` - The message to store

  ## Returns

  - `:ok` - If the message was enqueued successfully
  - `{:error, reason}` - If the message could not be enqueued
  """
  @spec enqueue_message(pid(), MessageEnvelope.t()) :: :ok | {:error, any()}
  def enqueue_message(mailbox_pid, message_envelope) do
    GenStage.cast(mailbox_pid, {:enqueue_message, message_envelope})
  end

  @doc """
  I get information about my current state.

  ## Parameters

  - `mailbox_pid` - My PID

  ## Returns

  - `{:ok, info}` - My current state information
  """
  @spec get_info(pid()) :: {:ok, map()}
  def get_info(mailbox_pid) do
    GenStage.call(mailbox_pid, :get_info)
  end

  # --- GenStage Callbacks --- #

  @impl GenStage
  def init({processing_engine_address, delivery_policy}) do
    # Initialize message store based on delivery policy
    message_store = MessageStore.new(delivery_policy)

    # Monitor the processing engine
    parent_ref =
      case processing_engine_address do
        {:engine, _node, _id} ->
          # In a full implementation, we'd monitor the actual process
          # For now, we'll skip monitoring
          nil

        _ ->
          nil
      end

    state = %State{
      processing_engine_address: processing_engine_address,
      message_store: message_store,
      delivery_policy: delivery_policy,
      parent_ref: parent_ref
    }

    Logger.info(
      "Mailbox engine started for #{inspect(processing_engine_address)} with policy #{inspect(delivery_policy)}"
    )

    {:producer, state}
  end

  @impl GenStage
  def handle_call(:get_info, _from, state) do
    info = %{
      processing_engine_address: state.processing_engine_address,
      delivery_policy: state.delivery_policy,
      pending_messages: MessageStore.size(state.message_store),
      total_received: state.total_messages_received,
      total_delivered: state.total_messages_delivered,
      current_demand: state.demand
    }

    {:reply, {:ok, info}, [], state}
  end

  @impl GenStage
  def handle_cast({:enqueue_message, message_envelope}, state) do
    # Implement formal m-Enqueue rule: store message in local state
    Logger.debug("Mailbox enqueuing message: #{inspect(message_envelope.message_id)}")

    # Store the message using our delivery policy
    new_message_store = MessageStore.insert(state.message_store, message_envelope)

    new_state = %{
      state
      | message_store: new_message_store,
        total_messages_received: state.total_messages_received + 1
    }

    # If there's demand, try to deliver messages immediately
    {events, final_state} =
      if state.demand > 0 do
        handle_demand(state.demand, new_state)
      else
        {[], new_state}
      end

    {:noreply, events, final_state}
  end

  @impl GenStage
  def handle_demand(demand, state) when demand > 0 do
    # Implement formal m-Dequeue rule: deliver messages according to policy
    Logger.debug(
      "Mailbox handling demand: #{demand}, available: #{MessageStore.size(state.message_store)}"
    )

    # Extract messages according to delivery policy
    {messages, new_message_store} = MessageStore.extract(state.message_store, demand)

    new_state = %{
      state
      | message_store: new_message_store,
        demand: max(0, demand - length(messages)),
        total_messages_delivered: state.total_messages_delivered + length(messages)
    }

    Logger.debug("Mailbox delivering #{length(messages)} messages")

    {:noreply, messages, new_state}
  end

  @impl GenStage
  def handle_info({:DOWN, ref, :process, _pid, _reason}, state) when ref == state.parent_ref do
    # Processing engine has terminated, we should also terminate
    Logger.info("Processing engine terminated, shutting down mailbox")
    {:stop, :normal, state}
  end

  def handle_info(msg, state) do
    Logger.warning("Mailbox engine received unexpected message: #{inspect(msg)}")
    {:noreply, [], state}
  end
end
