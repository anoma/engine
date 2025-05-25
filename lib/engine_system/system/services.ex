defmodule EngineSystem.System.Services do
  @moduledoc """
  I provide miscellaneous system-wide services and functions.

  This module implements system services like unique identifier generation
  and mailbox address lookup as specified in the formal model.

  ## Public API

  ### System Services
  - `fresh_id/0` - Generate a unique identifier for engine instances, messages, etc.
  - `mailbox_of_name/1` - Get the mailbox address for a given processing engine
  - `send_message/2` - Send a message to an engine (convenience function)
  - `get_system_info/0` - Get system-wide information and statistics

  ### Node Management
  - `create_node/1` - Create a new node in the system
  - `current_node_id/0` - Get the current node ID

  ### Validation and Cleanup
  - `validate_message/2` - Validate that a message conforms to an engine's interface
  - `clean_terminated_engines/0` - Clean up terminated engines from the system
  """

  alias EngineSystem.Engine.State
  alias EngineSystem.System.Registry

  @doc """
  I generate a unique identifier for engine instances, messages, etc.

  This implements the `freshid` function from the formal model.

  ## Returns

  A unique integer identifier.
  """
  @spec fresh_id() :: non_neg_integer()
  def fresh_id do
    Registry.fresh_id()
  end

  @doc """
  I get the mailbox address for a given processing engine.

  This implements the `mailboxOfname` function from the formal model.

  ## Parameters

  - `engine_address` - The address of the processing engine

  ## Returns

  - `{:ok, mailbox_address}` if the mailbox is found
  - `{:error, :not_found}` if the engine or its mailbox is not found
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

  This is a convenience function that handles message routing to the appropriate
  mailbox engine.

  ## Parameters

  - `target_address` - The address of the target engine
  - `message` - The message to send

  ## Returns

  - `:ok` if the message was sent successfully
  - `{:error, reason}` if sending failed
  """
  @spec send_message(State.address(), any()) :: :ok | {:error, any()}
  def send_message(target_address, _message) do
    case mailbox_of_name(target_address) do
      {:ok, _mailbox_address} ->
        # In a full implementation, this would route to the actual mailbox process
        # For now, we'll simulate successful sending
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  I create a new node in the system.

  This implements node creation as specified in the s-Node rule.

  ## Parameters

  - `node_plugins` - Optional plugins/services for the node

  ## Returns

  - `{:ok, node_id}` if the node was created successfully
  - `{:error, reason}` if creation failed
  """
  @spec create_node(map()) :: {:ok, non_neg_integer()} | {:error, any()}
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

  ## Returns

  A map containing system information.
  """
  @spec get_system_info() :: map()
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

  ## Parameters

  - `engine_address` - The target engine's address
  - `message` - The message to validate

  ## Returns

  - `:ok` if the message is valid
  - `{:error, reason}` if the message is invalid
  """
  @spec validate_message(State.address(), any()) :: :ok | {:error, any()}
  def validate_message(engine_address, message) do
    case Registry.lookup_instance(engine_address) do
      {:ok, %{spec_key: spec_key}} ->
        case Registry.lookup_spec(elem(spec_key, 0), elem(spec_key, 1)) do
          {:ok, spec} ->
            EngineSystem.Engine.Spec.validate_message(spec, message)

          {:error, :not_found} ->
            {:error, :spec_not_found}
        end

      {:error, :not_found} ->
        {:error, :engine_not_found}
    end
  end

  @doc """
  I clean up terminated engines from the system.

  This implements the s-Clean rule from the formal model.

  ## Returns

  The number of engines that were cleaned up.
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

  For now, this returns a default node ID since we're running on a single node.

  ## Returns

  The current node ID.
  """
  @spec current_node_id() :: non_neg_integer()
  def current_node_id do
    # In a distributed system, this would return the actual node ID
    # For now, we use a default value
    1
  end

  @doc """
  I generate a unique address for a new engine.

  ## Returns

  A new unique address tuple.
  """
  @spec generate_address() :: State.address()
  def generate_address do
    node_id = current_node_id()
    engine_id = fresh_id()
    {node_id, engine_id}
  end
end
