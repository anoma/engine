defmodule EngineSystem.API do
  @moduledoc """
  I provide the core API functions for the EngineSystem.

  I handle:
  - Engine spawning and termination
  - Message sending between engines
  - Engine specification management
  - Instance and system queries
  """

  alias EngineSystem.Engine.{Spec, State}
  alias EngineSystem.Mailbox.{DefaultMailboxEngine, Message}
  alias EngineSystem.System.{Registry, Services, Spawner}

  @doc """
  I spawn a new engine instance.

  ## Parameters

  - `engine_module` - The module that defines the engine using the DSL
  - `config` - Initial configuration for the engine (optional)
  - `environment` - Initial environment/local state for the engine (optional)
  - `name` - Optional name for the instance

  ## Returns

  - `{:ok, address}` if the engine was spawned successfully
  - `{:error, reason}` if spawning failed

  ## Examples

      # Spawn an engine with default configuration
      {:ok, address} = EngineSystem.API.spawn_engine(MyKVEngine)

      # Spawn with custom configuration
      config = %{access_mode: :read_only}
      {:ok, address} = EngineSystem.API.spawn_engine(MyKVEngine, config)

      # Spawn with a name
      {:ok, address} = EngineSystem.API.spawn_engine(MyKVEngine, nil, nil, :my_kv_store)
  """
  @spec spawn_engine(module(), any(), any(), atom() | nil) ::
          {:ok, State.address()} | {:error, any()}
  def spawn_engine(engine_module, config \\ nil, environment \\ nil, name \\ nil) do
    Spawner.spawn_engine(engine_module, config, environment, name)
  end

  @doc """
  I send a message to an engine.

  ## Parameters

  - `target_address` - The address of the target engine
  - `message_payload` - The message payload to send
  - `sender_address` - The sender's address (optional)

  ## Returns

  - `:ok` if the message was sent successfully
  - `{:error, reason}` if sending failed

  ## Examples

      # Send a simple message
      :ok = EngineSystem.API.send_message(target_address, {:get, :my_key})

      # Send with explicit sender
      :ok = EngineSystem.API.send_message(target_address, {:put, :key, :value}, sender_address)
  """
  @spec send_message(State.address(), any(), State.address() | nil) :: :ok | {:error, any()}
  def send_message(target_address, message_payload, sender_address \\ nil) do
    message = Message.new(sender_address, target_address, message_payload)

    with {:ok, _mailbox_address} <- Services.mailbox_of_name(target_address),
         {:ok, %{mailbox_pid: mailbox_pid}} when not is_nil(mailbox_pid) <-
           Registry.lookup_instance(target_address) do
      DefaultMailboxEngine.enqueue_message(mailbox_pid, message)
      :ok
    else
      {:ok, %{mailbox_pid: nil}} -> {:error, :no_mailbox}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  I terminate an engine instance.

  ## Parameters

  - `address` - The address of the engine to terminate

  ## Returns

  - `:ok` if termination succeeded
  - `{:error, reason}` if termination failed
  """
  @spec terminate_engine(State.address()) :: :ok | {:error, any()}
  def terminate_engine(address) do
    Spawner.terminate_engine(address)
  end

  @doc """
  I register an engine specification.

  This is typically called automatically when an engine module is compiled,
  but can be called manually if needed.

  ## Parameters

  - `spec` - The engine specification to register

  ## Returns

  - `:ok` if registration succeeded
  - `{:error, reason}` if registration failed
  """
  @spec register_spec(Spec.t()) :: :ok | {:error, any()}
  def register_spec(spec) do
    Registry.register_spec(spec)
  end

  @doc """
  I look up an engine specification by name and version.

  ## Parameters

  - `name` - The engine type name
  - `version` - The engine type version (nil for latest)

  ## Returns

  - `{:ok, spec}` if found
  - `{:error, :not_found}` if not found
  """
  @spec lookup_spec(atom() | String.t(), String.t() | nil) ::
          {:ok, Spec.t()} | {:error, :not_found}
  def lookup_spec(name, version \\ nil) do
    Registry.lookup_spec(name, version)
  end

  @doc """
  I list all running engine instances.

  ## Returns

  A list of instance information maps.
  """
  @spec list_instances() :: [Registry.instance_info()]
  def list_instances do
    Registry.list_instances()
  end

  @doc """
  I list all registered engine specifications.

  ## Returns

  A list of engine specifications.
  """
  @spec list_specs() :: [Spec.t()]
  def list_specs do
    Registry.list_specs()
  end

  @doc """
  I look up information about a running engine instance.

  ## Parameters

  - `address` - The engine's address

  ## Returns

  - `{:ok, info}` if the engine exists
  - `{:error, :not_found}` if the engine doesn't exist
  """
  @spec lookup_instance(State.address()) :: {:ok, Registry.instance_info()} | {:error, :not_found}
  def lookup_instance(address) do
    Registry.lookup_instance(address)
  end

  @doc """
  I look up an engine address by name.

  ## Parameters

  - `name` - The engine's name

  ## Returns

  - `{:ok, address}` if found
  - `{:error, :not_found}` if not found
  """
  @spec lookup_address_by_name(atom()) :: {:ok, State.address()} | {:error, :not_found}
  def lookup_address_by_name(name) do
    Registry.lookup_address_by_name(name)
  end

  @doc """
  I get system-wide information and statistics.

  ## Returns

  A map containing system information.
  """
  @spec get_system_info() :: map()
  def get_system_info do
    Services.get_system_info()
  end

  @doc """
  I generate a fresh unique ID.

  ## Returns

  A unique integer identifier.
  """
  @spec fresh_id() :: non_neg_integer()
  def fresh_id do
    Services.fresh_id()
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
    Services.validate_message(engine_address, message)
  end

  @doc """
  I clean up terminated engines from the system.

  ## Returns

  The number of engines that were cleaned up.
  """
  @spec clean_terminated_engines() :: non_neg_integer()
  def clean_terminated_engines do
    Services.clean_terminated_engines()
  end
end
