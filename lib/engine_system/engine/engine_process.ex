defmodule EngineSystem.Engine.EngineProcess do
  @moduledoc """
  I represent a running instance of an engine.

  I manage the lifecycle of an engine instance from initialization to termination,
  maintain its environment (local state), and handle its mailbox via a GenServer process.

  I'm responsible for:
  - Interpreting and executing compiled engine definitions
  - Maintaining the engine's environment (local state)
  - Processing messages according to the engine's guarded actions
  - Generating effects (sending messages, updating state, forking, etc.)
  - Handling engine lifecycle events

  ### Public API

  I have the following public functionality:

  - `start_link/3` - Start a new engine instance
  - `send_message/3` - Send a message to an engine instance
  - `get_info/1` - Get information about an engine instance
  - `get_status/1` - Get the current status of an engine instance
  - `terminate/1` - Terminate an engine instance
  """
  use GenServer
  require Logger

  alias EngineSystem.Engine.Compilation.Types.EngineSpec

  alias EngineSystem.Engine.EngineProcess.{
    MessageProcessor,
    StateManager,
    Types,
    Utils
  }

  alias EngineSystem.Types.{
    EngineMode,
    EngineStatus,
    MessageEnvelope,
    OperationResult
  }

  # --- Types --- #

  # Import shared types
  @type engine_address :: Types.engine_address()
  @type message_id :: Types.message_id()
  @type timestamp :: Types.timestamp()
  @type engine_type_name :: Types.engine_type_name()
  @type engine_version :: Types.engine_version()
  @type config :: Types.config()
  @type environment :: Types.environment()
  @type effect :: Types.effect()
  @type action_result :: Types.action_result()
  @type operational_mode :: Types.operational_mode()

  # --- State --- #

  defmodule State do
    @moduledoc false
    @enforce_keys [
      :engine_name,
      :address,
      :engine_spec,
      :config,
      :environment,
      :operational_mode
    ]

    @type t :: %__MODULE__{
            engine_name: String.t(),
            address: EngineSystem.Engine.EngineProcess.engine_address(),
            engine_spec: EngineSpec.t(),
            config: EngineSystem.Engine.EngineProcess.config(),
            environment: EngineSystem.Engine.EngineProcess.environment(),
            mailbox: [MessageEnvelope.t()],
            status: EngineStatus.t(MessageEnvelope.t()),
            creation_timestamp: EngineSystem.Engine.EngineProcess.timestamp(),
            last_status_change_timestamp: EngineSystem.Engine.EngineProcess.timestamp(),
            operational_mode: EngineMode.t(),
            pending_effects: [EngineSystem.Engine.EngineProcess.effect()]
          }

    defstruct engine_name: nil,
              address: nil,
              engine_spec: nil,
              config: nil,
              environment: nil,
              mailbox: [],
              # Will be set in init/1
              status: nil,
              # Will be set in init/1
              creation_timestamp: nil,
              # Will be set in init/1
              last_status_change_timestamp: nil,
              operational_mode: :process,
              pending_effects: []
  end

  # --- Public API --- #

  @doc """
  I start a new engine instance with the given type name, version, and configuration.

  ## Parameters

  - `engine_type_name` - The name of the engine type to instantiate
  - `engine_type_version` - The version of the engine type to instantiate
  - `config` - The configuration for the engine instance
  - `engine_spec` - (Optional) The engine spec to use, to avoid fetching it from the registry

  ## Returns

  - `{:ok, pid}` - If the engine was started successfully
  - `{:error, reason}` - If the engine could not be started
  """
  @spec start_link(
          engine_type_name(),
          engine_version(),
          config(),
          EngineSpec.t() | nil
        ) ::
          {:ok, pid()} | {:error, any()}
  def start_link(engine_type_name, engine_type_version, config, engine_spec \\ nil) do
    GenServer.start_link(
      __MODULE__,
      {engine_type_name, engine_type_version, config, engine_spec}
    )
  end

  @doc """
  I send a message to an engine instance.

  ## Parameters

  - `engine_pid` - The PID of the engine instance to send the message to
  - `message_tag` - The tag of the message to send
  - `payload` - The payload of the message (can be a single value or a tuple)

  ## Returns

  - `{:ok, message_id}` - If the message was sent successfully
  - `{:error, reason}` - If the message could not be sent
  """
  @spec send_message(pid(), atom(), any()) ::
          OperationResult.t()
  def send_message(engine_pid, message_tag, payload) do
    # Reconstruct the original message format for the envelope
    original_payload =
      if is_tuple(payload),
        do: Tuple.insert_at(payload, 0, message_tag),
        else: {message_tag, payload}

    GenServer.call(engine_pid, {:send_message, message_tag, payload, original_payload})
  end

  @doc """
  I get information about an engine instance.

  ## Parameters

  - `engine_pid` - The PID of the engine instance to get information about

  ## Returns

  - `{:ok, %EngineInstanceInfo{}}` - Information about the engine instance
  """
  @spec get_info(pid()) :: OperationResult.t()
  def get_info(engine_pid) do
    GenServer.call(engine_pid, :get_info)
  end

  @doc """
  I get the current status of an engine instance.

  ## Parameters

  - `engine_pid` - The PID of the engine instance to get the status of

  ## Returns

  - `{:ok, engine_status}` - The current status of the engine instance
  """
  @spec get_status(pid()) :: OperationResult.t()
  def get_status(engine_pid) do
    GenServer.call(engine_pid, :get_status)
  end

  @doc """
  I terminate an engine instance.

  ## Parameters

  - `engine_pid` - The PID of the engine instance to terminate

  ## Returns

  - `:ok` - If the engine was terminated successfully
  """
  @spec terminate(pid()) :: :ok
  def terminate(engine_pid) do
    GenServer.cast(engine_pid, :terminate)
  end

  # --- GenServer Callbacks --- #

  @impl GenServer
  def init({engine_type_name, engine_type_version, config, engine_spec}) do
    # Use the provided engine spec or fetch it from the registry
    engine_spec_result =
      if engine_spec do
        %OperationResult{status: :ok, value: engine_spec}
      else
        # Fetch the engine type spec from the registry
        EngineSystem.System.Services.get_engine_type_spec(engine_type_name, engine_type_version)
      end

    case engine_spec_result do
      %OperationResult{status: :ok, value: engine_spec} ->
        # Generate a unique address for this engine instance
        address = Utils.generate_engine_address()

        # Create the initial state
        # Extract operational_mode from config, default to :process if not present
        engine_op_mode = Map.get(config, :mode, :process)
        current_time = System.system_time(:millisecond)

        state = %State{
          engine_name: to_string(engine_type_name),
          address: address,
          engine_spec: engine_spec,
          config: config,
          environment: Utils.initialize_environment(engine_spec.env_spec),
          creation_timestamp: current_time,
          last_status_change_timestamp: current_time,
          status: {:ready, &EngineSystem.Types.EngineStatus.default_filter/1},
          mailbox: [],
          pending_effects: [],
          # Set from config
          operational_mode: engine_op_mode
        }

        # Register this engine instance with SystemServices
        EngineSystem.System.Services.register_engine_instance(
          address,
          self(),
          engine_type_name,
          engine_type_version
        )

        {:ok, state}

      %OperationResult{status: :error, reason: reason} ->
        {:stop, reason}
    end
  end

  @impl GenServer
  def handle_call({:send_message, message_tag, payload, original_payload}, from, state) do
    # Create a message envelope
    envelope = StateManager.create_message_envelope(message_tag, payload, original_payload, from)

    # Process the message based on the current status and operational mode
    case state.status do
      {:ready, filter_fun} ->
        if filter_fun.(envelope) do
          # Message matches current filter, process it by adding to mailbox for async processing
          new_state =
            state
            |> StateManager.add_message_to_mailbox(envelope)
            |> StateManager.transition_to_busy(envelope)

          # Schedule processing of the message
          Process.send_after(self(), {:process_mailbox}, 0)

          {:reply, OperationResult.ok(envelope.message_id), new_state}
        else
          # Message doesn't match current filter, add to mailbox
          new_state = StateManager.add_message_to_mailbox(state, envelope)
          {:reply, OperationResult.ok(envelope.message_id), new_state}
        end

      {:busy, _current_message} ->
        # Already processing a message, add to mailbox
        new_state = StateManager.add_message_to_mailbox(state, envelope)
        {:reply, OperationResult.ok(envelope.message_id), new_state}

      :terminated ->
        # Engine is terminating or terminated, reject the message
        {:reply, OperationResult.error(:engine_terminated), state}
    end
  end

  def handle_call(:get_info, _from, state) do
    # Create an EngineInstanceInfo struct
    info = StateManager.create_engine_info(state)
    {:reply, OperationResult.ok(info), state}
  end

  def handle_call(:get_status, _from, state) do
    {:reply, OperationResult.ok(state.status), state}
  end

  @impl GenServer
  def handle_cast(:terminate, state) do
    # Change the status to terminating
    new_state = StateManager.transition_to_terminated(state)

    # Schedule the termination process
    Process.send_after(self(), :do_terminate, 0)

    {:noreply, new_state}
  end

  @impl GenServer
  def handle_info({:process_mailbox}, state) do
    case state.status do
      {:busy, current_message} ->
        # Process the current message
        {new_state, _result} = MessageProcessor.process_message(current_message, state)

        # Update the status
        updated_state =
          case new_state.mailbox do
            [next_message | _] ->
              # Process the next message
              StateManager.transition_to_busy(new_state, next_message)

            [] ->
              # No more messages, set status to ready
              StateManager.transition_to_ready(new_state)
          end

        # Schedule processing of the next message if available
        if not Enum.empty?(updated_state.mailbox) do
          Process.send_after(self(), {:process_mailbox}, 0)
        end

        {:noreply, updated_state}

      _ ->
        # Not busy, no need to process mailbox
        {:noreply, state}
    end
  end

  def handle_info(:do_terminate, state) do
    # Handle termination cleanup
    new_state = StateManager.handle_termination_cleanup(state)

    # Terminate the process
    {:stop, :normal, new_state}
  end
end
