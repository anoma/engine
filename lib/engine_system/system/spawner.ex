defmodule EngineSystem.System.Spawner do
  @moduledoc """
  I am responsible for creating new engine instances along with their dedicated
  mailboxes.

  I implement the s-EngineSpawn operational rule from the formal model. The
  process involves fetching the Engine.Spec, starting a
  Mailbox.DefaultMailboxEngine, starting the Engine.Instance GenServer, and
  registering both with the System.Registry.

  ## Public API

  - `spawn_engine/4` - Spawn a new engine instance with optional config,
    environment and name
  """

  alias EngineSystem.Engine.{Instance, Spec, State}
  alias EngineSystem.Mailbox.DefaultMailboxEngine
  alias EngineSystem.System.{Registry, Services}
  alias EngineSystem.System.Spawner.{Logger, Validator}

  @doc """
  I spawn a new engine instance of the given type.

  This implements the complete s-EngineSpawn process:
  1. Fetch the Engine.Spec for the requested processing engine type
  2. Start an instance of the specified Mailbox Engine (or DefaultMailboxEngine) with the Engine.Spec
  3. Start the Engine.Instance GenServer with its spec and mailbox PID
  4. Register both with the System.Registry

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
    with {:ok, spec} <- get_engine_spec(engine_module),
         :ok <- validate_mailbox_compatibility(spec, mailbox_engine_module),
         {:ok, address} <- generate_address(),
         {:ok, mailbox_pid} <-
           start_mailbox_engine(spec, address, mailbox_engine_module, mailbox_config),
         {:ok, engine_pid} <-
           start_processing_engine(spec, address, mailbox_pid, config, environment),
         :ok <- update_mailbox_if_needed(mailbox_pid, address, engine_pid),
         :ok <- register_instance(address, spec, engine_pid, mailbox_pid, name) do
      {:ok, address}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  I spawn a new engine instance with full mailbox configuration.

  This provides explicit control over both processing and mailbox engines.

  ## Parameters

  - `opts` - Keyword list with:
    - `:processing_engine` - Processing engine module
    - `:processing_config` - Processing engine configuration
    - `:processing_env` - Processing engine environment
    - `:mailbox_engine` - Mailbox engine module
    - `:mailbox_config` - Mailbox engine configuration
    - `:name` - Optional instance name

  ## Returns

  - `{:ok, address}` if spawning succeeded
  - `{:error, reason}` if spawning failed
  """
  @spec spawn_engine_with_mailbox(keyword()) :: {:ok, State.address()} | {:error, any()}
  def spawn_engine_with_mailbox(opts) do
    processing_engine = Keyword.fetch!(opts, :processing_engine)
    processing_config = Keyword.get(opts, :processing_config)
    processing_env = Keyword.get(opts, :processing_env)
    mailbox_engine = Keyword.get(opts, :mailbox_engine)
    mailbox_config = Keyword.get(opts, :mailbox_config)
    name = Keyword.get(opts, :name)

    spawn_engine(
      processing_engine,
      processing_config,
      processing_env,
      name,
      mailbox_engine,
      mailbox_config
    )
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

  @spec start_mailbox_engine(Spec.t(), State.address(), module() | nil, any() | nil) ::
          {:ok, pid() | nil} | {:error, any()}
  defp start_mailbox_engine(spec, mailbox_address, mailbox_engine_module, mailbox_config) do
    # If the processing engine is itself a mailbox engine, we don't need a separate mailbox
    if spec.mode == :mailbox do
      # No separate mailbox needed - the engine itself will be the mailbox
      {:ok, nil}
    else
      # Use specified mailbox engine or default
      engine_module =
        mailbox_engine_module ||
          get_default_mailbox_module()

      # Get the engine spec from the mailbox module
      mailbox_spec = engine_module.__engine_spec__()

      # Create mailbox initialization data with processing engine spec for validation
      # The mailbox will be created with the processing engine address as parent
      # but we need to wait for the processing engine to be created to get its PID
      mailbox_init_data = %{
        address: mailbox_address,
        engine_module: engine_module,
        spec: mailbox_spec,
        configuration:
          Map.merge(mailbox_config || %{}, %{
            # Configuration for the mailbox includes the processing engine as parent
            # Will be updated after processing engine starts
            parent: nil,
            mode: :mailbox
          }),
        environment: %{
          # Initialize with processing engine spec for message validation
          pe_spec: spec,
          # Will be set when processing engine starts
          pe_address: nil
        }
      }

      # Start the mailbox using the core runtime implementation
      case DynamicSupervisor.start_child(
             EngineSystem.Engine.DynamicSupervisor,
             {EngineSystem.Mailbox.MailboxRuntime, mailbox_init_data}
           ) do
        {:ok, pid} -> {:ok, pid}
        {:error, reason} -> {:error, {:mailbox_start_failed, reason}}
      end
    end
  end

  @spec start_processing_engine(Spec.t(), State.address(), pid() | nil, any(), any()) ::
          {:ok, pid()} | {:error, any()}
  defp start_processing_engine(spec, address, mailbox_pid, config, environment) do
    case spec.mode do
      :mailbox ->
        # For mailbox engines, start using the runtime implementation
        start_mailbox_as_processing_engine(spec, address, config, environment)

      :process ->
        # For processing engines, start the regular instance
        start_regular_processing_engine(spec, address, mailbox_pid, config, environment)
    end
  end

  defp start_mailbox_as_processing_engine(spec, address, config, environment) do
    # Prepare mailbox initialization data for the runtime
    final_config = config || Spec.default_config(spec)
    final_environment = environment || Spec.default_environment(spec)

    mailbox_init_data = %{
      address: address,
      # The module that defined the engine
      engine_module: spec.name,
      spec: spec,
      configuration: final_config,
      environment: final_environment
    }

    # Start using the core MailboxRuntime implementation
    case DynamicSupervisor.start_child(
           EngineSystem.Engine.DynamicSupervisor,
           {EngineSystem.Mailbox.MailboxRuntime, mailbox_init_data}
         ) do
      {:ok, pid} -> {:ok, pid}
      {:error, reason} -> {:error, {:mailbox_engine_start_failed, reason}}
    end
  end

  defp start_regular_processing_engine(spec, address, mailbox_pid, config, environment) do
    # Prepare the configuration with proper parent reference
    # The processing engine's parent should be the mailbox engine's address, not the pid
    final_config = config || Spec.default_config(spec)

    # Convert mailbox_pid to a proper address format if needed
    # For now, we'll use nil as parent since the pid format doesn't match address type
    parent_address = nil
    engine_config = State.Configuration.new(parent_address, :process, final_config)

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

  # Get the default mailbox module
  defp get_default_mailbox_module do
    DefaultMailboxEngine.DefaultMailbox
  end

  @spec register_instance(State.address(), Spec.t(), pid(), pid() | nil, atom() | nil) ::
          :ok | {:error, any()}
  defp register_instance(address, spec, engine_pid, mailbox_pid, name) do
    # Validate inputs before registration
    with :ok <- Validator.validate_registration_inputs(address, spec, engine_pid, mailbox_pid),
         :ok <- Validator.validate_instance_name(name),
         spec_key = {spec.name, spec.version},
         :ok <- Registry.register_instance(address, spec_key, engine_pid, mailbox_pid, name) do
      # Log successful registration with relevant details
      Logger.log_successful_registration(address, spec, engine_pid, mailbox_pid, name)
      :ok
    else
      {:error, reason} = error ->
        # Log registration failure with context
        Logger.log_registration_failure(address, spec, engine_pid, mailbox_pid, name, reason)
        error
    end
  end

  @doc """
  I terminate an engine instance and its associated mailbox.

  ## Parameters

  - `address` - The address of the engine to terminate

  ## Returns

  - `:ok` if termination succeeded
  - `{:error, reason}` if termination failed
  """
  @spec terminate_engine(State.address()) :: :ok | {:error, :engine_not_found}
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
  @spec get_spawner_info() :: %{
          active_engines: non_neg_integer(),
          available_specs: non_neg_integer(),
          engine_supervisor: EngineSystem.Engine.DynamicSupervisor,
          mailbox_supervisor: EngineSystem.Mailbox.DynamicSupervisor
        }
  def get_spawner_info do
    %{
      engine_supervisor: EngineSystem.Engine.DynamicSupervisor,
      mailbox_supervisor: EngineSystem.Mailbox.DynamicSupervisor,
      active_engines: length(Registry.list_instances()),
      available_specs: length(Registry.list_specs())
    }
  end

  @spec validate_mailbox_compatibility(Spec.t(), module() | nil) :: :ok | {:error, any()}
  defp validate_mailbox_compatibility(processing_spec, mailbox_engine_module) do
    # Rule 1: Mailbox engines cannot have other mailboxes (prevent nesting)
    if processing_spec.mode == :mailbox and not is_nil(mailbox_engine_module) do
      {:error,
       {:mailbox_nesting_not_allowed,
        "Mailbox engines cannot have other mailboxes attached. This would create unnecessary complexity."}}
    else
      # Rule 2: Validate that if a custom mailbox is specified, it's actually a mailbox engine
      if mailbox_engine_module != nil do
        case get_engine_spec(mailbox_engine_module) do
          {:ok, mailbox_spec} ->
            if mailbox_spec.mode == :mailbox do
              :ok
            else
              {:error,
               {:invalid_mailbox_engine,
                "#{mailbox_engine_module} is not a mailbox engine (mode: #{mailbox_spec.mode})"}}
            end

          {:error, reason} ->
            {:error, {:invalid_mailbox_module, reason}}
        end
      else
        :ok
      end
    end
  end

  @spec update_mailbox_if_needed(pid() | nil, State.address(), pid()) ::
          :ok | {:error, {:mailbox_call_failed, any()}}
  defp update_mailbox_if_needed(nil, _pe_address, _engine_pid), do: :ok

  defp update_mailbox_if_needed(mailbox_pid, pe_address, engine_pid) when is_pid(mailbox_pid) do
    # Update the mailbox environment with the processing engine address and PID
    # This establishes the proper parent-child relationship where the processing engine is the parent
    case GenStage.call(mailbox_pid, {:update_pe_info, pe_address, engine_pid}) do
      :ok -> :ok
      {:error, reason} -> {:error, {:mailbox_call_failed, reason}}
    end
  end
end
