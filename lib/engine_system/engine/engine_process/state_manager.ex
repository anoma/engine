defmodule EngineSystem.Engine.EngineProcess.StateManager do
  @moduledoc """
  I handle state management and lifecycle transitions for engine processes.

  I'm responsible for:
  - Managing engine state transitions
  - Handling lifecycle events
  - Coordinating status changes
  """

  alias EngineSystem.Types.{MessageEnvelope, EngineInstanceInfo}
  alias EngineSystem.Engine.EngineProcess.Utils

  @type engine_address :: {:engine, node(), pos_integer()} | {:sender, pid()}
  @type config :: map()
  @type environment :: any()

  @doc """
  I create an EngineInstanceInfo struct from the current state.
  """
  @spec create_engine_info(any()) :: EngineInstanceInfo.t()
  def create_engine_info(state) do
    %EngineInstanceInfo{
      address: state.address,
      pid: self(),
      type_name: state.engine_name,
      type_version: state.engine_spec.type_version,
      status: state.status,
      creation_timestamp: state.creation_timestamp,
      last_status_change_timestamp: state.last_status_change_timestamp,
      operational_mode: state.operational_mode,
      mailbox_size: length(state.mailbox)
    }
  end

  @doc """
  I transition the engine to a busy state with a current message.
  """
  @spec transition_to_busy(any(), MessageEnvelope.t()) :: any()
  def transition_to_busy(state, envelope) do
    %{
      state
      | status: {:busy, envelope},
        last_status_change_timestamp: System.system_time(:millisecond)
    }
  end

  @doc """
  I transition the engine to a ready state with an optional filter.
  """
  @spec transition_to_ready(any(), (MessageEnvelope.t() -> boolean()) | nil) :: any()
  def transition_to_ready(state, filter_fun \\ nil) do
    filter = filter_fun || (&EngineSystem.Types.EngineStatus.default_filter/0)

    %{
      state
      | status: {:ready, filter},
        last_status_change_timestamp: System.system_time(:millisecond)
    }
  end

  @doc """
  I transition the engine to a terminated state.
  """
  @spec transition_to_terminated(%{
          :last_status_change_timestamp => any(),
          :status => any(),
          optional(any()) => any()
        }) :: %{
          :last_status_change_timestamp => integer(),
          :status => :terminated,
          optional(any()) => any()
        }
  def transition_to_terminated(state) do
    %{
      state
      | status: :terminated,
        last_status_change_timestamp: System.system_time(:millisecond)
    }
  end

  @doc """
  I add a message to the engine's mailbox.
  """
  @spec add_message_to_mailbox(any(), MessageEnvelope.t()) :: any()
  def add_message_to_mailbox(state, envelope) do
    %{state | mailbox: state.mailbox ++ [envelope]}
  end

  @doc """
  I get the next message from the mailbox if available.
  """
  @spec get_next_message(any()) :: {MessageEnvelope.t() | nil, any()}
  def get_next_message(state) do
    case state.mailbox do
      [next_message | remaining] ->
        {next_message, %{state | mailbox: remaining}}

      [] ->
        {nil, state}
    end
  end

  @doc """
  I check if the engine should process a message based on its current status.
  """
  @spec should_process_message?(any(), MessageEnvelope.t()) :: boolean()
  def should_process_message?(state, envelope) do
    case state.status do
      {:ready, filter_fun} ->
        filter_fun.(envelope)

      {:busy, _current_message} ->
        false

      :terminated ->
        false
    end
  end

  @doc """
  I create a message envelope from message components.
  """
  @spec create_message_envelope(atom(), any(), any(), GenServer.from()) :: MessageEnvelope.t()
  def create_message_envelope(_message_tag, _payload, original_payload, from) do
    sender_address = Utils.extract_sender_address(from)
    message_id = Utils.generate_message_id()
    timestamp = System.system_time(:millisecond)

    %MessageEnvelope{
      message_id: message_id,
      original_payload: original_payload,
      sender_address: sender_address,
      timestamp: timestamp
    }
  end

  @doc """
  I handle the termination cleanup process.
  """
  @spec handle_termination_cleanup(%{
          :last_status_change_timestamp => any(),
          :status => any(),
          optional(any()) => any()
        }) :: %{
          :last_status_change_timestamp => integer(),
          :status => :terminated,
          optional(any()) => any()
        }
  def handle_termination_cleanup(state) do
    # Unregister this engine instance from SystemServices
    EngineSystem.System.Services.unregister_engine_instance(state.address)

    # Change the status to terminated
    transition_to_terminated(state)
  end
end
