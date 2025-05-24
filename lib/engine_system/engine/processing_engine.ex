defmodule EngineSystem.Engine.ProcessingEngine do
  @moduledoc """
  I am a processing engine that implements the formal Engine Model's processing-mailbox separation.

  According to the paper, I am a GenStage Consumer that:
  - Subscribes to my dedicated mailbox engine (Producer)
  - Implements the formal m-Dequeue rule by pulling messages when ready
  - Processes messages according to my guarded actions
  - Maintains my local state (environment) and configuration

  I never receive messages directly - all messages are routed through my mailbox engine.
  This implements the core innovation of the paper: mailbox-as-actors architecture.
  """

  use GenStage
  require Logger

  alias EngineSystem.Types.{MessageEnvelope, OperationResult, EngineStatus}
  alias EngineSystem.Engine.Compilation.Types.EngineSpec
  alias EngineSystem.Engine.EngineProcess.{Utils, MessageProcessor, EffectProcessor}
  alias EngineSystem.Mailbox.MailboxEngine
  alias EngineSystem.MessagePassing.Router

  # --- Types --- #

  @type engine_address :: {:engine, node(), pos_integer()}
  @type config :: map()
  @type environment :: any()
  @type engine_status :: EngineStatus.t(MessageEnvelope.t())

  # --- State --- #

  defmodule State do
    @moduledoc false

    @enforce_keys [
      :engine_name,
      :address,
      :engine_spec,
      :config,
      :environment,
      :mailbox_address,
      :mailbox_pid
    ]

    @type t :: %__MODULE__{
            engine_name: String.t(),
            address: EngineSystem.Engine.ProcessingEngine.engine_address(),
            engine_spec: EngineSpec.t(),
            config: EngineSystem.Engine.ProcessingEngine.config(),
            environment: EngineSystem.Engine.ProcessingEngine.environment(),
            mailbox_address: EngineSystem.Engine.ProcessingEngine.engine_address(),
            mailbox_pid: pid(),
            status: EngineSystem.Engine.ProcessingEngine.engine_status(),
            creation_timestamp: integer(),
            last_status_change_timestamp: integer(),
            messages_processed: non_neg_integer(),
            current_message: MessageEnvelope.t() | nil
          }

    defstruct [
      :engine_name,
      :address,
      :engine_spec,
      :config,
      :environment,
      :mailbox_address,
      :mailbox_pid,
      status: {:ready, &EngineSystem.Types.EngineStatus.default_filter/0},
      creation_timestamp: 0,
      last_status_change_timestamp: 0,
      messages_processed: 0,
      current_message: nil
    ]
  end

  # --- Public API --- #

  @doc """
  I start a processing engine with its dedicated mailbox engine.

  This implements the formal model where every processing engine has a mailbox.

  ## Parameters

  - `engine_type_name` - The name of the engine type
  - `engine_type_version` - The version of the engine type
  - `config` - The configuration for the engine
  - `delivery_policy` - The mailbox delivery policy (default: :fifo)
  - `opts` - Additional options

  ## Returns

  - `{:ok, {processing_pid, mailbox_pid}}` - If both engines started successfully
  - `{:error, reason}` - If startup failed
  """
  @spec start_link(atom() | String.t(), String.t(), config(), atom(), keyword()) ::
          {:ok, {pid(), pid()}} | {:error, any()}
  def start_link(
        engine_type_name,
        engine_type_version,
        config,
        delivery_policy \\ :fifo,
        opts \\ []
      ) do
    # First get the engine spec
    case EngineSystem.System.Services.get_engine_type_spec(engine_type_name, engine_type_version) do
      %OperationResult{status: :ok, value: engine_spec} ->
        start_with_spec(
          engine_type_name,
          engine_type_version,
          config,
          delivery_policy,
          engine_spec,
          opts
        )

      %OperationResult{status: :error, reason: reason} ->
        {:error, reason}
    end
  end

  @doc """
  I get information about my current state.
  """
  @spec get_info(pid()) :: OperationResult.t()
  def get_info(processing_pid) do
    GenStage.call(processing_pid, :get_info)
  end

  @doc """
  I get my current status.
  """
  @spec get_status(pid()) :: OperationResult.t()
  def get_status(processing_pid) do
    GenStage.call(processing_pid, :get_status)
  end

  @doc """
  I terminate myself and my mailbox engine.
  """
  @spec terminate(pid()) :: :ok
  def terminate(processing_pid) do
    GenStage.cast(processing_pid, :terminate)
  end

  # --- GenStage Callbacks --- #

  @impl GenStage
  def init({engine_type_name, engine_type_version, config, delivery_policy, engine_spec}) do
    # Generate addresses
    processing_address = Utils.generate_engine_address()
    mailbox_address = Utils.generate_engine_address()

    # Start the mailbox engine first
    case MailboxEngine.start_link(processing_address, delivery_policy) do
      {:ok, mailbox_pid} ->
        # Register the mailbox with the router
        :ok = Router.register_mailbox(processing_address, mailbox_address, mailbox_pid)

        # Initialize state
        current_time = System.system_time(:millisecond)

        state = %State{
          engine_name: to_string(engine_type_name),
          address: processing_address,
          engine_spec: engine_spec,
          config: config,
          environment: Utils.initialize_environment(engine_spec.env_spec),
          mailbox_address: mailbox_address,
          mailbox_pid: mailbox_pid,
          creation_timestamp: current_time,
          last_status_change_timestamp: current_time
        }

        # Register with system services
        EngineSystem.System.Services.register_engine_instance(
          processing_address,
          self(),
          engine_type_name,
          engine_type_version
        )

        Logger.info(
          "Processing engine #{inspect(processing_address)} started with mailbox #{inspect(mailbox_address)}"
        )

        # Subscribe to mailbox engine (Consumer subscribes to Producer)
        GenStage.async_subscribe(self(), to: mailbox_pid, max_demand: 1)

        {:consumer, state}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl GenStage
  def handle_call(:get_info, _from, state) do
    info = %{
      address: state.address,
      pid: self(),
      type_name: state.engine_name,
      type_version: state.engine_spec.type_version,
      status: state.status,
      creation_timestamp: state.creation_timestamp,
      last_status_change_timestamp: state.last_status_change_timestamp,
      operational_mode: :process,
      mailbox_address: state.mailbox_address,
      messages_processed: state.messages_processed
    }

    {:reply, OperationResult.ok(info), [], state}
  end

  def handle_call(:get_status, _from, state) do
    {:reply, OperationResult.ok(state.status), [], state}
  end

  @impl GenStage
  def handle_cast(:terminate, state) do
    Logger.info("Processing engine #{inspect(state.address)} terminating")

    # Unregister mailbox
    Router.unregister_mailbox(state.address)

    # Terminate mailbox engine
    GenStage.stop(state.mailbox_pid, :normal)

    # Update status
    new_state = %{
      state
      | status: :terminated,
        last_status_change_timestamp: System.system_time(:millisecond)
    }

    {:stop, :normal, new_state}
  end

  @impl GenStage
  def handle_events(events, _from, state) do
    # Implement formal m-Dequeue rule: process messages from mailbox
    Logger.debug(
      "Processing engine #{inspect(state.address)} received #{length(events)} messages"
    )

    # Process each message (in practice, we usually process one at a time)
    final_state =
      Enum.reduce(events, state, fn message_envelope, acc_state ->
        process_message(message_envelope, acc_state)
      end)

    # Request more messages if we're ready
    demand = if final_state.status == :terminated, do: 0, else: 1

    {:noreply, [], final_state, demand}
  end

  @impl GenStage
  def handle_info({:DOWN, _ref, :process, pid, reason}, state) when pid == state.mailbox_pid do
    Logger.error("Mailbox engine died: #{inspect(reason)}")
    {:stop, :mailbox_died, state}
  end

  def handle_info(msg, state) do
    Logger.warning("Processing engine received unexpected message: #{inspect(msg)}")
    {:noreply, [], state}
  end

  # --- Private Functions --- #

  @spec start_with_spec(
          atom() | String.t(),
          String.t(),
          config(),
          atom(),
          EngineSpec.t(),
          keyword()
        ) ::
          {:ok, {pid(), pid()}} | {:error, any()}
  defp start_with_spec(
         engine_type_name,
         engine_type_version,
         config,
         delivery_policy,
         engine_spec,
         opts
       ) do
    case GenStage.start_link(
           __MODULE__,
           {engine_type_name, engine_type_version, config, delivery_policy, engine_spec},
           opts
         ) do
      {:ok, processing_pid} ->
        # Get the mailbox PID from the processing engine
        case get_info(processing_pid) do
          %OperationResult{status: :ok, value: info} ->
            # Find the mailbox PID - this is a simplification
            # In a real implementation, we'd return both PIDs from init
            {:ok, {processing_pid, info.mailbox_address}}

          error ->
            GenStage.stop(processing_pid)
            {:error, error}
        end

      error ->
        error
    end
  end

  @spec process_message(MessageEnvelope.t(), State.t()) :: State.t()
  defp process_message(message_envelope, state) do
    Logger.debug("Processing message: #{inspect(message_envelope.message_id)}")

    # Update status to busy
    busy_state = %{
      state
      | status: {:busy, message_envelope},
        current_message: message_envelope,
        last_status_change_timestamp: System.system_time(:millisecond)
    }

    # Use existing message processor
    {updated_state, _result} = MessageProcessor.process_message(message_envelope, busy_state)

    # Update status back to ready
    ready_state = %{
      updated_state
      | status: {:ready, &EngineSystem.Types.EngineStatus.default_filter/0},
        current_message: nil,
        messages_processed: state.messages_processed + 1,
        last_status_change_timestamp: System.system_time(:millisecond)
    }

    ready_state
  end
end
