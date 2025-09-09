defmodule EngineSystem.API do
  require Logger

  @moduledoc """
  I provide the core API functions for engine spawning, termination, message passing, and system management.
  """

  alias EngineSystem.Engine.{Spec, State}
  alias EngineSystem.Lifecycle
  alias EngineSystem.System.{Registry, Services, Spawner}

  @doc """
  I start the EngineSystem application with all necessary supervisors and services.
  """
  @spec start_system() :: {:ok, [atom()]} | {:error, any()}
  def start_system do
    Lifecycle.start()
  end

  @doc """
  I stop the EngineSystem application gracefully with coordinated shutdown.
  """
  @spec stop_system() :: :ok
  def stop_system do
    Lifecycle.stop()
  end

  @doc """
  I spawn a new engine instance with optional configuration and mailbox setup.
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
  I spawn a new engine instance with explicit mailbox configuration from keyword options.
  """
  @spec spawn_engine_with_mailbox(keyword()) :: {:ok, State.address()} | {:error, any()}
  def spawn_engine_with_mailbox(opts) do
    Spawner.spawn_engine_with_mailbox(opts)
  end

  @doc """
  I send a message payload to a target engine with optional sender address.
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
  I terminate an engine instance gracefully and clean up its resources.
  """
  @spec terminate_engine(State.address()) :: :ok | {:error, :engine_not_found}
  def terminate_engine(address) do
    Spawner.terminate_engine(address)
  end

  @doc """
  I register an engine specification with the system registry.
  """
  @spec register_spec(Spec.t()) :: :ok | {:error, any()}
  def register_spec(spec) do
    Registry.register_spec(spec)
  end

  @doc """
  I look up an engine specification by name and version.
  """
  @spec lookup_spec(atom() | String.t(), String.t() | nil) ::
          {:ok, Spec.t()} | {:error, :not_found}
  def lookup_spec(name, version \\ nil) do
    Registry.lookup_spec(name, version)
  end

  @doc """
  I list all running engine instances.
  """
  @spec list_instances() :: [Registry.instance_info()]
  def list_instances do
    Registry.list_instances()
  end

  @doc """
  I list all registered engine specifications.
  """
  @spec list_specs() :: [Spec.t()]
  def list_specs do
    Registry.list_specs()
  end

  @doc """
  I look up information about a running engine instance by address.
  """
  @spec lookup_instance(State.address()) :: {:ok, Registry.instance_info()} | {:error, :not_found}
  def lookup_instance(address) do
    Registry.lookup_instance(address)
  end

  @doc """
  I look up an engine address by name.
  """
  @spec lookup_address_by_name(atom()) :: {:ok, State.address()} | {:error, :not_found}
  def lookup_address_by_name(name) do
    Registry.lookup_address_by_name(name)
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
    Services.get_system_info()
  end

  @doc """
  I generate a fresh unique ID.
  """
  @spec fresh_id() :: non_neg_integer()
  def fresh_id do
    Services.fresh_id()
  end

  @doc """
  I validate that a message conforms to an engine's interface.
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
  I clean up terminated engines from the system registry.
  """
  @spec clean_terminated_engines() :: non_neg_integer()
  def clean_terminated_engines do
    Services.clean_terminated_engines()
  end

  @doc """
  I check if an engine specification supports a specific message tag.
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
  I get the field specification for a message tag from an engine specification.
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
  I get all message tags supported by an engine specification.
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
  I get all message tags supported by a running engine instance.
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
