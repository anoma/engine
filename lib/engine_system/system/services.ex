defmodule EngineSystem.System.Services do
  @moduledoc """
  I provide system-wide services including unique ID generation, mailbox lookup, and message validation.
  """

  alias EngineSystem.Engine.{Spec, State}
  alias EngineSystem.Mailbox.MailboxRuntime
  alias EngineSystem.System.Registry

  @doc """
  I generate a unique identifier for engine instances and messages.
  """
  @spec fresh_id() :: non_neg_integer()
  def fresh_id do
    Registry.fresh_id()
  end

  @doc """
  I get the mailbox address for a given processing engine.
  """
  @spec mailbox_of_name(State.address()) :: {:ok, State.address()} | {:error, :not_found}
  def mailbox_of_name(engine_address) do
    case Registry.lookup_instance(engine_address) do
      {:ok, %{mailbox_pid: mailbox_pid}} when not is_nil(mailbox_pid) ->
        # For now, we'll construct the mailbox address based on the engine address
        # In a full implementation, this would be properly tracked
        {node_id, engine_id} = engine_address
        # Simple offset for demo
        mailbox_address = {node_id, engine_id + 1000}
        {:ok, mailbox_address}

      {:ok, %{mailbox_pid: nil}} ->
        {:error, :no_mailbox}

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end

  @doc """
  I send a message to an engine.
  """
  @spec send_message(State.address(), any()) :: :ok | {:error, :not_found}
  def send_message(target_address, message) do
    # Emit telemetry for runtime flow tracking
    message_type =
      case message.payload do
        {tag, _} -> tag
        tag when is_atom(tag) -> tag
        _ -> :unknown
      end

    start_time = :erlang.system_time(:millisecond)

    result =
      case Registry.lookup_instance(target_address) do
        {:ok, %{mailbox_pid: mailbox_pid}} when not is_nil(mailbox_pid) ->
          # Send the message to the mailbox engine using the MailboxRuntime
          MailboxRuntime.enqueue_message(mailbox_pid, message)
          :ok

        {:ok, %{mailbox_pid: nil}} ->
          # Engine has no mailbox, send directly to the engine process
          case Registry.lookup_instance(target_address) do
            {:ok, %{engine_pid: engine_pid}} ->
              # Extract message parts
              {message_tag, payload} =
                case message.payload do
                  {tag, p} -> {tag, p}
                  tag when is_atom(tag) -> {tag, %{}}
                  other -> {:unknown, other}
                end

              # Send directly to engine using GenServer call
              GenServer.cast(engine_pid, {:message, message_tag, payload, message.header.sender})
              :ok

            {:error, _} ->
              {:error, :engine_not_found}
          end

        {:error, :not_found} ->
          {:error, :not_found}
      end

    # Emit telemetry after message sending attempt
    end_time = :erlang.system_time(:millisecond)
    duration = end_time - start_time

    case result do
      :ok ->
        :telemetry.execute(
          [:engine_system, :message, :sent],
          %{count: 1, duration: duration},
          %{
            source_engine: message.sender,
            target_engine: target_address,
            message_type: message_type,
            payload: message.payload,
            success: true
          }
        )

      {:error, reason} ->
        :telemetry.execute(
          [:engine_system, :message, :failed],
          %{count: 1, duration: duration},
          %{
            source_engine: message.sender,
            target_engine: target_address,
            message_type: message_type,
            payload: message.payload,
            success: false,
            error_reason: reason
          }
        )
    end

    result
  end

  @doc """
  I create a new node in the system.
  """
  @spec create_node(map()) :: {:ok, non_neg_integer()}
  def create_node(_node_plugins \\ %{}) do
    node_id = fresh_id()

    # In a full implementation, this would:
    # 1. Create the node structure
    # 2. Initialize node-specific services
    # 3. Register the node in the system

    {:ok, node_id}
  end

  @doc """
  I get system-wide information and statistics.
  """
  @spec get_system_info() :: %{
          library_version: any(),
          running_instances: non_neg_integer(),
          system_uptime: integer(),
          total_instances: non_neg_integer(),
          total_specs: non_neg_integer()
        }
  def get_system_info do
    instances = Registry.list_instances()
    specs = Registry.list_specs()

    %{
      total_instances: length(instances),
      total_specs: length(specs),
      running_instances: Enum.count(instances, fn info -> info.status == :running end),
      system_uptime: :erlang.system_time(:millisecond),
      library_version: Application.spec(:engine_system, :vsn) || "unknown"
    }
  end

  @doc """
  I validate that a message conforms to an engine's interface.
  """
  @spec validate_message(State.address(), any()) ::
          :ok | {:error, :engine_not_found | :spec_not_found | {:unknown_message_tag, any()}}
  def validate_message(engine_address, message) do
    case Registry.lookup_instance(engine_address) do
      {:ok, %{spec_key: spec_key}} ->
        case Registry.lookup_spec(elem(spec_key, 0), elem(spec_key, 1)) do
          {:ok, spec} ->
            Spec.validate_message(spec, message)

          {:error, :not_found} ->
            {:error, :spec_not_found}
        end

      {:error, :not_found} ->
        {:error, :engine_not_found}
    end
  end

  @doc """
  I clean up terminated engines from the system.
  """
  @spec clean_terminated_engines() :: non_neg_integer()
  def clean_terminated_engines do
    instances = Registry.list_instances()

    terminated_count =
      instances
      |> Enum.filter(fn info -> info.status == :terminated end)
      |> Enum.map(fn info ->
        Registry.unregister_instance(info.address)
        info
      end)
      |> length()

    terminated_count
  end

  @doc """
  I get the current node ID.
  """
  @spec current_node_id() :: 1
  def current_node_id do
    # In a distributed system, this would return the actual node ID
    # For now, we use a default value
    1
  end

  @doc """
  I generate a unique address for a new engine.
  """
  @spec generate_address() :: State.address()
  def generate_address do
    node_id = current_node_id()
    engine_id = fresh_id()
    {node_id, engine_id}
  end
end
