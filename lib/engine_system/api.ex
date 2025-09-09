defmodule EngineSystem.API do
  require Logger

  @moduledoc """
  I provide the core API functions for the EngineSystem.

  I handle:
  - Engine spawning and termination
  - Message sending between engines
  - Engine specification management
  - Instance and system queries
  - System lifecycle management

  ## Public API

  ### System Lifecycle
  - `start_system/0` - Start the EngineSystem application
  - `stop_system/0` - Stop the EngineSystem application

  ### Engine Management
  - `spawn_engine/4` - Spawn a new engine instance
  - `terminate_engine/1` - Terminate an engine instance
  - `send_message/3` - Send a message to an engine

  ### Instance Management
  - `list_instances/0` - List all running engine instances
  - `lookup_instance/1` - Look up information about a running engine instance
  - `lookup_address_by_name/1` - Look up an engine address by name

  ### Engine Specifications
  - `register_spec/1` - Register an engine specification
  - `lookup_spec/2` - Look up an engine specification by name and version
  - `list_specs/0` - List all registered engine specifications

  ### System Operations
  - `get_system_info/0` - Get system-wide information and statistics
  - `fresh_id/0` - Generate a fresh unique ID
  - `validate_message/2` - Validate that a message conforms to an engine's interface
  - `clean_terminated_engines/0` - Clean up terminated engines from the system

  ### Interface Utilities
  - `has_message?/3` - Check if an engine specification supports a specific message tag
  - `get_message_fields/3` - Get the field specification for a message tag from an engine specification
  - `get_message_tags/2` - Get all message tags supported by an engine specification
  - `get_instance_message_tags/1` - Get all message tags supported by a running engine instance
  """

  alias EngineSystem.Engine.{Spec, State}
  alias EngineSystem.Lifecycle
  alias EngineSystem.System.{Registry, Services, Spawner}

  @doc """
  Starts the EngineSystem application.

  Initializes the complete OTP application with all necessary supervisors and services.

  ## Returns

  - `{:ok, [app_list]}` if the system started successfully
  - `{:error, reason}` if startup failed
  """
  @spec start_system() :: {:ok, [atom()]} | {:error, any()}
  def start_system do
    Lifecycle.start()
  end

  @doc """
  Stops the EngineSystem application gracefully.

  Performs coordinated shutdown of all system components including running engines and cleanup.

  ## Returns

  `:ok` when the system has been stopped completely.
  """
  @spec stop_system() :: :ok
  def stop_system do
    Lifecycle.stop()
  end

  @doc """
  Spawns a new engine instance.

  ## Parameters

  - `engine_module` - The module that defines the engine using the DSL
  - `config` - Initial configuration for the engine (optional)
  - `environment` - Initial environment/local state for the engine (optional)
  - `name` - Optional name for the instance
  - `mailbox_engine_module` - Optional mailbox engine module (defaults to DefaultMailboxEngine)
  - `mailbox_config` - Optional mailbox engine configuration

  ## Returns

  - `{:ok, address}` if the engine was spawned successfully
  - `{:error, reason}` if spawning failed
  """
  @spec spawn_engine(module(), any(), any(), atom() | nil, module() | nil, any() | nil) ::
          {:ok, State.address()} | {:error, any()}
  def spawn_engine(
        engine_module,
        config \\ nil,
        environment \\ nil,
        name \\ nil,
        mailbox_engine_module \\ nil,
        mailbox_config \\ nil
      ) do
    Spawner.spawn_engine(
      engine_module,
      config,
      environment,
      name,
      mailbox_engine_module,
      mailbox_config
    )
  end

  @doc """
  Spawns a new engine instance with explicit mailbox configuration.

  ## Parameters

  - `opts` - Keyword list with configuration options

  ## Returns

  - `{:ok, address}` if the engine was spawned successfully
  - `{:error, reason}` if spawning failed
  """
  @spec spawn_engine_with_mailbox(keyword()) :: {:ok, State.address()} | {:error, any()}
  def spawn_engine_with_mailbox(opts) do
    Spawner.spawn_engine_with_mailbox(opts)
  end

  @doc """
  Sends a message to an engine.

  ## Parameters

  - `target_address` - The address of the target engine
  - `message_payload` - The message payload to send
  - `sender_address` - The sender's address (optional)

  ## Returns

  - `:ok` if sending succeeded
  - `{:error, reason}` if sending failed
  """
  @spec send_message(State.address(), any(), State.address() | nil) :: :ok | {:error, :not_found}
  def send_message(target_address, message_payload, sender_address \\ nil) do
    # Create a proper message struct for the system
    # Use proper address format: {node_id, engine_id} where both are non_neg_integer
    # System address using proper format
    sender_addr = sender_address || {0, 0}
    message = EngineSystem.System.Message.new(sender_addr, target_address, message_payload)

    # Use the Services.send_message function for actual sending
    Services.send_message(target_address, message)
  end

  @doc """
  Terminates an engine instance gracefully.

  Stops a running engine and cleans up its resources, including mailbox and associated processes.

  ## Parameters

  - `address` - The address of the engine to terminate

  ## Returns

  - `:ok` if termination succeeded
  - `{:error, :engine_not_found}` if the engine doesn't exist
  - `{:error, reason}` if termination failed for other reasons
  """
  @spec terminate_engine(State.address()) :: :ok | {:error, :engine_not_found}
  def terminate_engine(address) do
    Spawner.terminate_engine(address)
  end

  @doc """
  Registers an engine specification with the system.

  Typically called automatically when an engine module is compiled.

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
  Looks up information about a running engine instance.

  ## Parameters

  - `address` - The engine's address

  ## Returns

  - `{:ok, info}` if the engine exists, containing address, status, spec info, process IDs, and timestamps
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
  Gets system-wide information and statistics.

  ## Returns

  A map containing system metrics including library version, instance counts, specs, and uptime.
  """
  @spec get_system_info() :: %{
          library_version: any(),
          running_instances: non_neg_integer(),
          system_uptime: integer(),
          total_instances: non_neg_integer(),
          total_specs: non_neg_integer()
        }
  def get_system_info do
    Services.get_system_info()
  end

  @doc """
  Generates a fresh unique ID.

  ## Returns

  A unique integer identifier.
  """
  @spec fresh_id() :: non_neg_integer()
  def fresh_id do
    Services.fresh_id()
  end

  @doc """
  Validates that a message conforms to an engine's interface.

  ## Parameters

  - `engine_address` - The target engine's address
  - `message` - The message to validate

  ## Returns

  - `:ok` if the message is valid
  - `{:error, reason}` if the message is invalid
  """
  @spec validate_message(State.address(), any()) ::
          :ok
          | {:error,
             :engine_not_found
             | :spec_not_found
             | {:unknown_message_tag, any()}}
  def validate_message(engine_address, message) do
    Services.validate_message(engine_address, message)
  end

  @doc """
  Cleans up terminated engines from the system registry.

  Removes terminated engine instances to free up memory and maintain system organization.

  ## Returns

  The number of engines that were cleaned up.
  """
  @spec clean_terminated_engines() :: non_neg_integer()
  def clean_terminated_engines do
    Services.clean_terminated_engines()
  end

  @doc """
  Checks if an engine specification supports a specific message tag.

  ## Parameters

  - `name` - The engine type name
  - `version` - The engine type version (nil for latest)
  - `tag` - Message tag to check

  ## Returns

  - `{:ok, true}` if the tag exists
  - `{:ok, false}` if the tag does not exist
  - `{:error, :not_found}` if the spec is not found
  """
  @spec has_message?(atom() | String.t(), String.t() | nil, atom()) ::
          {:ok, boolean()} | {:error, :not_found}
  def has_message?(name, version, tag) do
    case lookup_spec(name, version) do
      {:ok, spec} -> {:ok, Spec.has_message?(spec, tag)}
      {:error, :not_found} -> {:error, :not_found}
    end
  end

  @doc """
  Gets the field specification for a message tag from an engine specification.

  ## Parameters

  - `name` - The engine type name
  - `version` - The engine type version (nil for latest)
  - `tag` - Message tag to find

  ## Returns

  - `{:ok, fields}` if found
  - `{:error, :not_found}` if not found (either spec or message tag)
  """
  @spec get_message_fields(atom() | String.t(), String.t() | nil, atom()) ::
          {:ok, Spec.message_fields()} | {:error, :not_found}
  def get_message_fields(name, version, tag) do
    case lookup_spec(name, version) do
      {:ok, spec} -> Spec.get_message_fields(spec, tag)
      {:error, :not_found} -> {:error, :not_found}
    end
  end

  @doc """
  Gets all message tags supported by an engine specification.

  ## Parameters

  - `name` - The engine type name
  - `version` - The engine type version (nil for latest)

  ## Returns

  - `{:ok, tags}` if found
  - `{:error, :not_found}` if not found
  """
  @spec get_message_tags(atom() | String.t(), String.t() | nil) ::
          {:ok, [atom()]} | {:error, :not_found}
  def get_message_tags(name, version) do
    case lookup_spec(name, version) do
      {:ok, spec} -> {:ok, Spec.get_message_tags(spec)}
      {:error, :not_found} -> {:error, :not_found}
    end
  end

  @doc """
  Gets all message tags supported by a running engine instance.

  ## Parameters

  - `address` - The engine's address

  ## Returns

  - `{:ok, tags}` if found
  - `{:error, :not_found}` if not found
  """
  @spec get_instance_message_tags(State.address()) ::
          {:ok, [atom()]} | {:error, :not_found}
  def get_instance_message_tags(address) do
    case Registry.lookup_instance(address) do
      {:ok, instance_info} ->
        # Get the spec using the spec_key from instance_info
        {name, version} = instance_info.spec_key

        case Registry.lookup_spec(name, version) do
          {:ok, spec} -> {:ok, Spec.get_message_tags(spec)}
          {:error, :not_found} -> {:error, :not_found}
        end

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end
end
