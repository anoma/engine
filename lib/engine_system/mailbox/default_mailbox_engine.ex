defmodule EngineSystem.Mailbox.DefaultMailboxEngine do
  @moduledoc """
  Mailbox engine implementing the mailbox-as-actors pattern from the formal paper.

  This GenStage producer acts as a first-class actor following Definition 2.16
  from "ART-Mailboxes-actors/main.tex". It implements the core innovation of
  promoting mailboxes to first-class processing engines.

  ## Paper References

  - **Definition 2.16 (Mailbox Engine)**: Mailbox as first-class actor
  - **Section 2.6**: Mailbox Engines and mailbox-as-actors pattern
  - **Definition 3.2 (m-Send)**: Message sending mechanism
  - **Definition 3.3 (m-Enqueue)**: Message enqueuing in mailbox
  - **Definition 3.4 (m-Dequeue)**: Message dequeuing from mailbox
  - **Equation 2.17**: Message reception ⟨L_m, incoming(msg)⟩ → ⟨L_m ⊕ msg, ε⟩
  - **Equation 2.18**: Message delivery ⟨L_m, request()⟩ → ⟨L_m ⊖ msg, deliver(msg)⟩

  ## Key Properties from Paper

  1. Operational mode is set to `:mail`
  2. Parent reference points to paired processing engine
  3. Fixed message interface: append(MsgType_p)
  4. Maintains message store with insertion/deletion operations (⊕, ⊖)
  5. Defines custom message handling policies

  This implements the m-Send, m-Enqueue, and m-Dequeue rules from the operational semantics.
  """

  use GenStage
  use TypedStruct

  alias EngineSystem.Engine.{Spec, State}
  alias EngineSystem.Mailbox.Message

  typedstruct do
    @typedoc """
    I define the structure for a default mailbox engine.

    ### Fields

    - `:address` - The mailbox's address. Enforced: true.
    - `:processing_engine_spec` - The associated processing engine's spec. Enforced: true.
    - `:message_interface` - The message interface from the spec. Enforced: true.
    - `:message_filter` - The message filter function. Enforced: true.
    - `:message_queue` - The message queue. Enforced: false.
    - `:current_demand` - The current demand from consumers. Enforced: false.
    - `:total_received` - Total messages received. Enforced: false.
    - `:total_delivered` - Total messages delivered. Enforced: false.
    """
    field(:address, State.address(), enforce: true)
    field(:processing_engine_spec, Spec.t(), enforce: true)
    field(:message_interface, Spec.message_interface(), enforce: true)
    field(:message_filter, function(), enforce: true)
    field(:message_queue, :queue.queue(Message.t()), enforce: false, default: :queue.new())
    field(:current_demand, non_neg_integer(), enforce: false, default: 0)
    field(:total_received, non_neg_integer(), enforce: false, default: 0)
    field(:total_delivered, non_neg_integer(), enforce: false, default: 0)
  end

  ## Client API

  @doc """
  I start a mailbox engine for a processing engine.

  ## Parameters

  - `mailbox_spec` - Map containing:
    - `:address` - The mailbox's address
    - `:processing_engine_spec` - The associated processing engine's spec
    - `:message_interface` - The message interface from the spec
    - `:message_filter` - The message filter function

  ## Returns

  GenStage start result.
  """
  @spec start_link(map()) :: GenServer.on_start()
  def start_link(mailbox_spec) do
    GenStage.start_link(__MODULE__, mailbox_spec)
  end

  @doc """
  I enqueue a message for the processing engine.

  This implements the m-Send and m-Enqueue rules from the formal model.

  ## Parameters

  - `mailbox_pid` - The mailbox PID
  - `message` - The message to enqueue

  ## Returns

  `:ok` if the message was enqueued successfully.
  """
  @spec enqueue_message(pid(), Message.t()) :: :ok
  def enqueue_message(mailbox_pid, message) do
    GenStage.cast(mailbox_pid, {:enqueue_message, message})
  end

  @doc """
  I update the message filter function.

  ## Parameters

  - `mailbox_pid` - The mailbox PID
  - `new_filter` - The new filter function

  ## Returns

  `:ok` if the filter was updated successfully.
  """
  @spec update_filter(pid(), function()) :: :ok
  def update_filter(mailbox_pid, new_filter) do
    GenStage.call(mailbox_pid, {:update_filter, new_filter})
  end

  @doc """
  I get information about the mailbox state.

  ## Parameters

  - `mailbox_pid` - The mailbox PID

  ## Returns

  A map with mailbox information.
  """
  @spec get_info(pid()) :: map()
  def get_info(mailbox_pid) do
    GenStage.call(mailbox_pid, :get_info)
  end

  ## GenStage Callbacks

  @impl true
  def init(mailbox_spec) do
    state = %__MODULE__{
      address: mailbox_spec.address,
      processing_engine_spec: mailbox_spec.processing_engine_spec,
      message_interface: mailbox_spec.message_interface,
      message_filter: mailbox_spec.message_filter,
      message_queue: :queue.new(),
      current_demand: 0,
      total_received: 0,
      total_delivered: 0
    }

    {:producer, state}
  end

  @impl true
  def handle_demand(demand, state) do
    # Update current demand
    new_demand = state.current_demand + demand
    new_state = %{state | current_demand: new_demand}

    # Try to dispatch messages if we have any
    {events, final_state} = dispatch_messages(new_state)

    {:noreply, events, final_state}
  end

  @impl true
  def handle_cast({:enqueue_message, message}, state) do
    # Validate message against interface
    case validate_message_interface(message, state.message_interface) do
      :ok ->
        # Enqueue the message
        new_queue = :queue.in(message, state.message_queue)
        new_state = %{state | message_queue: new_queue, total_received: state.total_received + 1}

        # Try to dispatch if there's demand
        {events, final_state} = dispatch_messages(new_state)
        {:noreply, events, final_state}

      {:error, _reason} ->
        # Invalid message, ignore it (could log or send to dead letter queue)
        {:noreply, [], state}
    end
  end

  @impl true
  def handle_call({:update_filter, new_filter}, _from, state) do
    new_state = %{state | message_filter: new_filter}
    {:reply, :ok, [], new_state}
  end

  @impl true
  def handle_call(:get_info, _from, state) do
    info = %{
      address: state.address,
      queue_size: :queue.len(state.message_queue),
      current_demand: state.current_demand,
      total_received: state.total_received,
      total_delivered: state.total_delivered,
      processing_engine_spec: state.processing_engine_spec.name
    }

    {:reply, info, [], state}
  end

  ## Private Functions

  @spec dispatch_messages(t()) :: {[Message.t()], t()}
  defp dispatch_messages(state) do
    dispatch_messages_acc(state, [])
  end

  @spec dispatch_messages_acc(t(), [Message.t()]) :: {[Message.t()], t()}
  defp dispatch_messages_acc(%{current_demand: 0} = state, acc) do
    # No demand, return accumulated events
    {Enum.reverse(acc), state}
  end

  defp dispatch_messages_acc(state, acc) do
    case :queue.out(state.message_queue) do
      {:empty, _queue} ->
        # No more messages, return accumulated events
        {Enum.reverse(acc), state}

      {{:value, message}, new_queue} ->
        # Check if message passes the filter
        if apply_message_filter(message, state.message_filter) do
          # Message passes filter, dispatch it
          new_state = %{
            state
            | message_queue: new_queue,
              current_demand: state.current_demand - 1,
              total_delivered: state.total_delivered + 1
          }

          dispatch_messages_acc(new_state, [message | acc])
        else
          # Message filtered out, try next message
          new_state = %{state | message_queue: new_queue}
          dispatch_messages_acc(new_state, acc)
        end
    end
  end

  @spec validate_message_interface(Message.t(), Spec.message_interface()) :: :ok | {:error, any()}
  defp validate_message_interface(message, interface) do
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

  @spec apply_message_filter(Message.t(), function()) :: boolean()
  defp apply_message_filter(message, filter_fn) do
    # Apply filter with simplified arguments for now
    # In a full implementation, this would pass proper config and env data
    filter_fn.(message.payload, %{}, %{})
  rescue
    _error ->
      # If filter fails, default to accepting the message
      true
  end
end
