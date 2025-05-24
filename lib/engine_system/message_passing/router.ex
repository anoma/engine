defmodule EngineSystem.MessagePassing.Router do
  @moduledoc """
  I implement the formal message-passing mechanism from the Engine Model.

  According to the paper, I am responsible for implementing the crucial m-Send rule:
  When a message is sent to a processing engine, I automatically route it to
  that engine's dedicated mailbox engine instead.

  This is the core innovation of the paper - decoupling message reception from processing.
  """

  use GenServer
  require Logger

  alias EngineSystem.Types.{MessageEnvelope, OperationResult}
  alias EngineSystem.Mailbox.MailboxEngine
  alias EngineSystem.Engine.EngineProcess

  # --- Types --- #

  @type engine_address :: {:engine, node(), pos_integer()}
  @type mailbox_mapping :: %{engine_address() => pid()}

  # --- State --- #

  defmodule State do
    @moduledoc false

    @type t :: %__MODULE__{
            mailbox_registry: EngineSystem.MessagePassing.Router.mailbox_mapping(),
            processing_to_mailbox: %{
              EngineSystem.MessagePassing.Router.engine_address() =>
                EngineSystem.MessagePassing.Router.engine_address()
            },
            total_messages_routed: non_neg_integer()
          }

    defstruct mailbox_registry: %{},
              processing_to_mailbox: %{},
              total_messages_routed: 0
  end

  # --- Public API --- #

  @doc """
  I start the message router.
  """
  @spec start_link(keyword()) :: {:ok, pid()} | {:error, any()}
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, [], opts ++ [name: __MODULE__])
  end

  @doc """
  I implement the formal m-Send rule by routing messages to mailbox engines.

  This is the core of the paper's innovation:
  - If target engine is a processing engine, route to its mailbox
  - If target engine is already a mailbox engine, send directly

  ## Parameters

  - `sender_address` - Address of the sending engine
  - `target_address` - Address of the target engine (processing engine)
  - `message` - The message to send

  ## Returns

  - `{:ok, message_id}` - If message was routed successfully
  - `{:error, reason}` - If routing failed
  """
  @spec send_message(engine_address(), engine_address(), tuple()) :: OperationResult.t()
  def send_message(sender_address, target_address, message) do
    GenServer.call(__MODULE__, {:send_message, sender_address, target_address, message})
  end

  @doc """
  I register a mailbox engine for a processing engine.

  This establishes the mailbox-to-processing engine relationship required by the formal model.

  ## Parameters

  - `processing_address` - Address of the processing engine
  - `mailbox_address` - Address of the mailbox engine
  - `mailbox_pid` - PID of the mailbox engine process

  ## Returns

  - `:ok` - If registration was successful
  - `{:error, reason}` - If registration failed
  """
  @spec register_mailbox(engine_address(), engine_address(), pid()) :: :ok | {:error, any()}
  def register_mailbox(processing_address, mailbox_address, mailbox_pid) do
    GenServer.call(
      __MODULE__,
      {:register_mailbox, processing_address, mailbox_address, mailbox_pid}
    )
  end

  @doc """
  I unregister a mailbox engine.

  ## Parameters

  - `processing_address` - Address of the processing engine

  ## Returns

  - `:ok` - Always succeeds
  """
  @spec unregister_mailbox(engine_address()) :: :ok
  def unregister_mailbox(processing_address) do
    GenServer.cast(__MODULE__, {:unregister_mailbox, processing_address})
  end

  @doc """
  I get the mailbox address for a processing engine.

  This implements the mailboxOf function from the formal model.

  ## Parameters

  - `processing_address` - Address of the processing engine

  ## Returns

  - `{:ok, mailbox_address}` - If mailbox is found
  - `{:error, :not_found}` - If no mailbox is registered
  """
  @spec get_mailbox_address(engine_address()) :: {:ok, engine_address()} | {:error, :not_found}
  def get_mailbox_address(processing_address) do
    GenServer.call(__MODULE__, {:get_mailbox_address, processing_address})
  end

  @doc """
  I get router statistics.
  """
  @spec get_stats() :: {:ok, map()}
  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  # --- GenServer Callbacks --- #

  @impl GenServer
  def init([]) do
    Logger.info("Message router started")
    {:ok, %State{}}
  end

  @impl GenServer
  def handle_call({:send_message, sender_address, target_address, message}, _from, state) do
    # Implement formal m-Send rule: route to mailbox engine
    Logger.debug(
      "Router: Sending message from #{inspect(sender_address)} to #{inspect(target_address)}"
    )

    case route_message(sender_address, target_address, message, state) do
      {:ok, message_id, new_state} ->
        {:reply, OperationResult.ok(message_id), new_state}

      {:error, reason, new_state} ->
        {:reply, OperationResult.error(reason), new_state}
    end
  end

  def handle_call(
        {:register_mailbox, processing_address, mailbox_address, mailbox_pid},
        _from,
        state
      ) do
    Logger.info(
      "Router: Registering mailbox #{inspect(mailbox_address)} for processing engine #{inspect(processing_address)}"
    )

    # Monitor the mailbox process
    Process.monitor(mailbox_pid)

    new_state = %{
      state
      | mailbox_registry: Map.put(state.mailbox_registry, mailbox_address, mailbox_pid),
        processing_to_mailbox:
          Map.put(state.processing_to_mailbox, processing_address, mailbox_address)
    }

    {:reply, :ok, new_state}
  end

  def handle_call({:get_mailbox_address, processing_address}, _from, state) do
    case Map.get(state.processing_to_mailbox, processing_address) do
      nil ->
        {:reply, {:error, :not_found}, state}

      mailbox_address ->
        {:reply, {:ok, mailbox_address}, state}
    end
  end

  def handle_call(:get_stats, _from, state) do
    stats = %{
      registered_mailboxes: map_size(state.mailbox_registry),
      processing_engines: map_size(state.processing_to_mailbox),
      total_messages_routed: state.total_messages_routed
    }

    {:reply, {:ok, stats}, state}
  end

  @impl GenServer
  def handle_cast({:unregister_mailbox, processing_address}, state) do
    mailbox_address = Map.get(state.processing_to_mailbox, processing_address)

    new_state = %{
      state
      | mailbox_registry: Map.delete(state.mailbox_registry, mailbox_address),
        processing_to_mailbox: Map.delete(state.processing_to_mailbox, processing_address)
    }

    {:noreply, new_state}
  end

  @impl GenServer
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    # Remove any mailbox registrations for the dead process
    Logger.info("Router: Cleaning up dead mailbox process #{inspect(pid)}")

    # Find and remove the mailbox from registry
    {mailbox_address, _} =
      Enum.find(state.mailbox_registry, {nil, nil}, fn {_addr, p} -> p == pid end)

    # Find and remove the processing engine mapping
    {processing_address, _} =
      Enum.find(state.processing_to_mailbox, {nil, nil}, fn {_proc, mail} ->
        mail == mailbox_address
      end)

    new_state = %{
      state
      | mailbox_registry: Map.delete(state.mailbox_registry, mailbox_address),
        processing_to_mailbox: Map.delete(state.processing_to_mailbox, processing_address)
    }

    {:noreply, new_state}
  end

  # --- Private Functions --- #

  @spec route_message(engine_address(), engine_address(), tuple(), State.t()) ::
          {:ok, String.t(), State.t()} | {:error, any(), State.t()}
  defp route_message(sender_address, target_address, message, state) do
    # Determine the actual destination based on engine type
    actual_destination = determine_destination(target_address, state)

    case actual_destination do
      {:mailbox, mailbox_address, mailbox_pid} ->
        # Send to mailbox engine (implements m-Enqueue)
        deliver_to_mailbox(sender_address, mailbox_address, mailbox_pid, message, state)

      {:processing, processing_address} ->
        # Send directly to processing engine (fallback for engines without mailboxes)
        deliver_to_processing_engine(sender_address, processing_address, message, state)

      {:error, reason} ->
        {:error, reason, state}
    end
  end

  @spec determine_destination(engine_address(), State.t()) ::
          {:mailbox, engine_address(), pid()} | {:processing, engine_address()} | {:error, any()}
  defp determine_destination(target_address, state) do
    # Check if target has a registered mailbox (this is a processing engine)
    case Map.get(state.processing_to_mailbox, target_address) do
      nil ->
        # No mailbox registered, check if target itself is a mailbox
        case Map.get(state.mailbox_registry, target_address) do
          nil ->
            # Neither processing engine with mailbox nor mailbox engine
            {:processing, target_address}

          mailbox_pid ->
            # Target is a mailbox engine
            {:mailbox, target_address, mailbox_pid}
        end

      mailbox_address ->
        # Target is a processing engine, route to its mailbox
        case Map.get(state.mailbox_registry, mailbox_address) do
          nil ->
            {:error, :mailbox_not_found}

          mailbox_pid ->
            {:mailbox, mailbox_address, mailbox_pid}
        end
    end
  end

  @spec deliver_to_mailbox(engine_address(), engine_address(), pid(), tuple(), State.t()) ::
          {:ok, String.t(), State.t()} | {:error, any(), State.t()}
  defp deliver_to_mailbox(sender_address, mailbox_address, mailbox_pid, message, state) do
    # Create message envelope
    message_envelope = create_message_envelope(sender_address, mailbox_address, message)

    # Send to mailbox engine using m-Enqueue rule
    case MailboxEngine.enqueue_message(mailbox_pid, message_envelope) do
      :ok ->
        new_state = %{state | total_messages_routed: state.total_messages_routed + 1}
        {:ok, message_envelope.message_id, new_state}

      {:error, reason} ->
        {:error, reason, state}
    end
  end

  @spec deliver_to_processing_engine(engine_address(), engine_address(), tuple(), State.t()) ::
          {:ok, String.t(), State.t()} | {:error, any(), State.t()}
  defp deliver_to_processing_engine(sender_address, target_address, message, state) do
    # Fallback: send directly to processing engine (old behavior)
    Logger.warning("Router: No mailbox found for #{inspect(target_address)}, sending directly")

    case EngineSystem.System.Services.send_message(target_address, message) do
      %OperationResult{status: :ok, value: message_id} ->
        new_state = %{state | total_messages_routed: state.total_messages_routed + 1}
        {:ok, message_id, new_state}

      %OperationResult{status: :error, reason: reason} ->
        {:error, reason, state}
    end
  end

  @spec create_message_envelope(engine_address(), engine_address(), tuple()) ::
          MessageEnvelope.t()
  defp create_message_envelope(sender_address, target_address, message) do
    %MessageEnvelope{
      message_id: generate_message_id(),
      original_payload: message,
      sender_address: sender_address,
      timestamp: System.system_time(:millisecond)
    }
  end

  @spec generate_message_id() :: String.t()
  defp generate_message_id do
    # Generate a unique message ID
    case Code.ensure_loaded(UUID) do
      {:module, UUID} ->
        try do
          UUID.uuid4()
        rescue
          _ -> "msg_#{System.unique_integer([:positive])}"
        end

      {:error, _} ->
        "msg_#{System.unique_integer([:positive])}"
    end
  end
end
