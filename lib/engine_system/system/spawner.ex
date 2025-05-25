defmodule EngineSystem.System.Spawner do
  @moduledoc """
  I am responsible for creating new engine instances along with their dedicated mailboxes.

  I implement the s-EngineSpawn operational rule from the formal model. The process
  involves fetching the Engine.Spec, starting a Mailbox.DefaultMailboxEngine,
  starting the Engine.Instance GenServer, and registering both with the System.Registry.
  """

  alias EngineSystem.Engine.{Instance, Spec, State}
  alias EngineSystem.Mailbox.DefaultMailboxEngine
  alias EngineSystem.System.{Registry, Services}

  @doc """
  I spawn a new engine instance of the given type.

  This implements the complete s-EngineSpawn process:
  1. Fetch the Engine.Spec for the requested processing engine type
  2. Start an instance of Mailbox.DefaultMailboxEngine with the Engine.Spec
  3. Start the Engine.Instance GenServer with its spec and mailbox PID
  4. Register both with the System.Registry

  ## Parameters

  - `engine_module` - The module that defines the engine using the DSL
  - `config` - Initial configuration for the engine (optional)
  - `environment` - Initial environment/local state for the engine (optional)
  - `name` - Optional name for the instance

  ## Returns

  - `{:ok, address}` if the engine was spawned successfully
  - `{:error, reason}` if spawning failed
  """
  @spec spawn_engine(module(), any(), any(), atom() | nil) ::
          {:ok, State.address()} | {:error, any()}
  def spawn_engine(engine_module, config \\ nil, environment \\ nil, name \\ nil) do
    with {:ok, spec} <- get_engine_spec(engine_module),
         {:ok, address} <- generate_address(),
         {:ok, mailbox_pid} <- start_mailbox_engine(spec, address),
         {:ok, engine_pid} <-
           start_processing_engine(spec, address, mailbox_pid, config, environment),
         :ok <- register_instance(address, spec, engine_pid, mailbox_pid, name) do
      {:ok, address}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  I spawn a mailbox engine for an existing processing engine.

  ## Parameters

  - `processing_engine_address` - The address of the processing engine
  - `spec` - The engine specification

  ## Returns

  - `{:ok, mailbox_address}` if the mailbox was spawned successfully
  - `{:error, reason}` if spawning failed
  """
  @spec spawn_mailbox_for_engine(State.address(), Spec.t()) ::
          {:ok, State.address()} | {:error, any()}
  def spawn_mailbox_for_engine(processing_engine_address, spec) do
    with {:ok, mailbox_address} <- generate_mailbox_address(processing_engine_address),
         {:ok, mailbox_pid} <- start_mailbox_engine(spec, mailbox_address) do
      # Update the processing engine's registry entry with the mailbox PID
      case Registry.lookup_instance(processing_engine_address) do
        {:ok, instance_info} ->
          _updated_info = %{instance_info | mailbox_pid: mailbox_pid}
          # In a full implementation, we'd update the registry entry
          {:ok, mailbox_address}

        {:error, reason} ->
          # Clean up the mailbox if we can't find the processing engine
          DynamicSupervisor.terminate_child(EngineSystem.Mailbox.DynamicSupervisor, mailbox_pid)
          {:error, reason}
      end
    end
  end

  ## Private Functions

  @spec get_engine_spec(module()) :: {:ok, Spec.t()} | {:error, any()}
  defp get_engine_spec(engine_module) do
    spec = engine_module.__engine_spec__()
    {:ok, spec}
  rescue
    UndefinedFunctionError ->
      {:error, {:invalid_engine_module, engine_module}}

    error ->
      {:error, {:spec_error, error}}
  end

  @spec generate_address() :: {:ok, State.address()}
  defp generate_address do
    address = Services.generate_address()
    {:ok, address}
  end

  @spec generate_mailbox_address(State.address()) :: {:ok, State.address()}
  defp generate_mailbox_address({node_id, engine_id}) do
    # Generate a related but unique address for the mailbox
    # Simple offset strategy
    mailbox_id = engine_id + 1000
    {:ok, {node_id, mailbox_id}}
  end

  @spec start_mailbox_engine(Spec.t(), State.address()) :: {:ok, pid()} | {:error, any()}
  defp start_mailbox_engine(spec, mailbox_address) do
    mailbox_spec = %{
      address: mailbox_address,
      processing_engine_spec: spec,
      message_interface: spec.interface,
      message_filter: Spec.get_message_filter(spec)
    }

    case DynamicSupervisor.start_child(
           EngineSystem.Mailbox.DynamicSupervisor,
           {DefaultMailboxEngine, mailbox_spec}
         ) do
      {:ok, pid} -> {:ok, pid}
      {:error, reason} -> {:error, {:mailbox_start_failed, reason}}
    end
  end

  @spec start_processing_engine(Spec.t(), State.address(), pid(), any(), any()) ::
          {:ok, pid()} | {:error, any()}
  defp start_processing_engine(spec, address, mailbox_pid, config, environment) do
    # Prepare the configuration
    final_config = config || Spec.default_config(spec)
    engine_config = State.Configuration.new(nil, :process, final_config)

    # Prepare the environment
    final_environment = environment || Spec.default_environment(spec)
    engine_env = State.Environment.new(final_environment, %{self: address})

    # Prepare the initial status
    message_filter = Spec.get_message_filter(spec)
    initial_status = State.Status.ready(message_filter)

    engine_init_data = %{
      address: address,
      spec: spec,
      configuration: engine_config,
      environment: engine_env,
      status: initial_status,
      mailbox_pid: mailbox_pid
    }

    case DynamicSupervisor.start_child(
           EngineSystem.Engine.DynamicSupervisor,
           {Instance, engine_init_data}
         ) do
      {:ok, pid} -> {:ok, pid}
      {:error, reason} -> {:error, {:engine_start_failed, reason}}
    end
  end

  @spec register_instance(State.address(), Spec.t(), pid(), pid(), atom() | nil) ::
          :ok | {:error, any()}
  defp register_instance(address, spec, engine_pid, mailbox_pid, name) do
    spec_key = {spec.name, spec.version}
    Registry.register_instance(address, spec_key, engine_pid, mailbox_pid, name)
  end

  @doc """
  I terminate an engine instance and its associated mailbox.

  ## Parameters

  - `address` - The address of the engine to terminate

  ## Returns

  - `:ok` if termination succeeded
  - `{:error, reason}` if termination failed
  """
  @spec terminate_engine(State.address()) :: :ok | {:error, any()}
  def terminate_engine(address) do
    case Registry.lookup_instance(address) do
      {:ok, %{engine_pid: engine_pid, mailbox_pid: mailbox_pid}} ->
        # Terminate the processing engine
        if Process.alive?(engine_pid) do
          DynamicSupervisor.terminate_child(EngineSystem.Engine.DynamicSupervisor, engine_pid)
        end

        # Terminate the mailbox engine
        if mailbox_pid && Process.alive?(mailbox_pid) do
          DynamicSupervisor.terminate_child(EngineSystem.Mailbox.DynamicSupervisor, mailbox_pid)
        end

        # Unregister from the registry
        Registry.unregister_instance(address)

        :ok

      {:error, :not_found} ->
        {:error, :engine_not_found}
    end
  end

  @doc """
  I get information about the spawning capabilities and current state.

  ## Returns

  A map with spawning statistics and capabilities.
  """
  @spec get_spawner_info() :: map()
  def get_spawner_info do
    %{
      engine_supervisor: EngineSystem.Engine.DynamicSupervisor,
      mailbox_supervisor: EngineSystem.Mailbox.DynamicSupervisor,
      active_engines: length(Registry.list_instances()),
      available_specs: length(Registry.list_specs())
    }
  end
end
