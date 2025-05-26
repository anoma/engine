defmodule EngineSystem.System.Registry do
  @moduledoc """
  I am a GenServer acting as a global registry.

  I track registered Engine.Specs (engine types and versions) and running
  Engine.Instance PIDs and their associated Mailbox.DefaultMailboxEngine PIDs,
  mapping them by user-defined names or generated IDs.

  I provide functions for looking up engine specs, instance PIDs, and mailbox PIDs.

  ## Public API

  ### Engine Specifications

  - `register_spec/1` - Register an engine specification
  - `lookup_spec/2` - Look up an engine specification by name and version
  - `list_specs/0` - List all registered engine specifications

  ### Engine Instances

  - `register_instance/5` - Register a running engine instance
  - `lookup_instance/1` - Look up information about a running engine instance
  - `lookup_address_by_name/1` - Look up an engine address by name
  - `unregister_instance/1` - Unregister an engine instance
  - `list_instances/0` - List all running engine instances

  ### Utilities

  - `fresh_id/0` - Generate a fresh unique ID
  - `start_link/1` - Start the registry GenServer
  """

  use GenServer

  alias EngineSystem.Engine.Spec
  alias EngineSystem.Engine.State

  # {name, version}
  @type spec_key :: {atom(), String.t()}
  @type instance_key :: State.address()
  @type instance_info :: %{
          address: State.address(),
          spec_key: spec_key(),
          mailbox_pid: pid() | nil,
          engine_pid: pid(),
          status: atom(),
          created_at: DateTime.t()
        }

  use TypedStruct

  typedstruct do
    @typedoc """
    I define the structure for the system registry.

    ### Fields

    - `:specs` - Map of spec_key => Spec.t(). Enforced: false.
    - `:instances` - Map of instance_key => instance_info(). Enforced: false.
    - `:name_to_address` - Map of name => address (for named instances). Enforced: false.
    - `:next_id` - Counter for generating unique IDs. Enforced: false.
    """
    field(:specs, %{spec_key() => Spec.t()}, enforce: false, default: %{})
    field(:instances, %{State.address() => instance_info()}, enforce: false, default: %{})
    field(:name_to_address, %{atom() => State.address()}, enforce: false, default: %{})
    field(:next_id, non_neg_integer(), enforce: false, default: 1)
  end

  ## Client API

  @doc """
  I start the registry GenServer.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, [], name: name)
  end

  @doc """
  I register an engine specification.

  ## Parameters

  - `spec` - The engine specification to register

  ## Returns

  - `:ok` if registration succeeded
  - `{:error, reason}` if registration failed
  """
  @spec register_spec(Spec.t()) :: :ok | {:error, any()}
  def register_spec(spec) do
    GenServer.call(__MODULE__, {:register_spec, spec})
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
    GenServer.call(__MODULE__, {:lookup_spec, name, version})
  end

  @doc """
  I register a running engine instance.

  ## Parameters

  - `address` - The engine's address
  - `spec_key` - The spec key {name, version}
  - `engine_pid` - The engine's PID
  - `mailbox_pid` - The mailbox's PID (optional)
  - `name` - Optional name for the instance

  ## Returns

  - `:ok` if registration succeeded
  - `{:error, reason}` if registration failed
  """
  @spec register_instance(State.address(), spec_key(), pid(), pid() | nil, atom() | nil) ::
          :ok | {:error, any()}
  def register_instance(address, spec_key, engine_pid, mailbox_pid \\ nil, name \\ nil) do
    GenServer.call(
      __MODULE__,
      {:register_instance, address, spec_key, engine_pid, mailbox_pid, name}
    )
  end

  @doc """
  I look up information about a running engine instance.

  ## Parameters

  - `address` - The engine's address

  ## Returns

  - `{:ok, info}` if the engine exists
  - `{:error, :not_found}` if the engine doesn't exist
  """
  @spec lookup_instance(State.address()) :: {:ok, instance_info()} | {:error, :not_found}
  def lookup_instance(address) do
    GenServer.call(__MODULE__, {:lookup_instance, address})
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
    GenServer.call(__MODULE__, {:lookup_address_by_name, name})
  end

  @doc """
  I unregister an engine instance.

  ## Parameters

  - `address` - The engine's address

  ## Returns

  - `:ok` if unregistration succeeded
  - `{:error, :not_found}` if the engine wasn't found
  """
  @spec unregister_instance(State.address()) :: :ok | {:error, :not_found}
  def unregister_instance(address) do
    GenServer.call(__MODULE__, {:unregister_instance, address})
  end

  @doc """
  I list all running engine instances.

  ## Returns

  A list of instance information maps.
  """
  @spec list_instances() :: [instance_info()]
  def list_instances do
    GenServer.call(__MODULE__, :list_instances)
  end

  @doc """
  I list all registered engine specifications.

  ## Returns

  A list of engine specifications.
  """
  @spec list_specs() :: [Spec.t()]
  def list_specs do
    GenServer.call(__MODULE__, :list_specs)
  end

  @doc """
  I generate a fresh unique ID.

  ## Returns

  A unique integer ID.
  """
  @spec fresh_id() :: non_neg_integer()
  def fresh_id do
    GenServer.call(__MODULE__, :fresh_id)
  end

  ## Server Callbacks

  @impl true
  def init([]) do
    {:ok, %__MODULE__{}}
  end

  @impl true
  def handle_call({:register_spec, spec}, _from, state) do
    spec_key = {spec.name, spec.version}

    case Map.get(state.specs, spec_key) do
      nil ->
        new_specs = Map.put(state.specs, spec_key, spec)
        new_state = %{state | specs: new_specs}
        {:reply, :ok, new_state}

      _existing ->
        {:reply, {:error, :already_registered}, state}
    end
  end

  @impl true
  def handle_call({:lookup_spec, name, version}, _from, state) do
    name_atom = if is_binary(name), do: String.to_atom(name), else: name

    result =
      if version do
        # Look for specific version
        case Map.get(state.specs, {name_atom, version}) do
          nil -> {:error, :not_found}
          spec -> {:ok, spec}
        end
      else
        # Look for latest version
        matching_specs =
          state.specs
          |> Enum.filter(fn {{spec_name, _version}, _spec} -> spec_name == name_atom end)
          |> Enum.sort_by(fn {{_name, version}, _spec} -> version end, :desc)

        case matching_specs do
          [] -> {:error, :not_found}
          [{_key, spec} | _] -> {:ok, spec}
        end
      end

    {:reply, result, state}
  end

  @impl true
  def handle_call(
        {:register_instance, address, spec_key, engine_pid, mailbox_pid, name},
        _from,
        state
      ) do
    # Check for address conflicts first
    case Map.get(state.instances, address) do
      nil ->
        # Check for name conflicts if a name is provided
        case check_name_conflict(name, state.name_to_address) do
          :ok ->
            instance_info = %{
              address: address,
              spec_key: spec_key,
              mailbox_pid: mailbox_pid,
              engine_pid: engine_pid,
              status: :running,
              created_at: DateTime.utc_now()
            }

            new_instances = Map.put(state.instances, address, instance_info)

            new_name_to_address =
              if name do
                Map.put(state.name_to_address, name, address)
              else
                state.name_to_address
              end

            new_state = %{state | instances: new_instances, name_to_address: new_name_to_address}

            {:reply, :ok, new_state}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end

      _existing ->
        {:reply, {:error, :address_already_registered}, state}
    end
  end

  @impl true
  def handle_call({:lookup_instance, address}, _from, state) do
    result =
      case Map.get(state.instances, address) do
        nil -> {:error, :not_found}
        info -> {:ok, info}
      end

    {:reply, result, state}
  end

  @impl true
  def handle_call({:lookup_address_by_name, name}, _from, state) do
    result =
      case Map.get(state.name_to_address, name) do
        nil -> {:error, :not_found}
        address -> {:ok, address}
      end

    {:reply, result, state}
  end

  @impl true
  def handle_call({:unregister_instance, address}, _from, state) do
    case Map.get(state.instances, address) do
      nil ->
        {:reply, {:error, :not_found}, state}

      _info ->
        new_instances = Map.delete(state.instances, address)

        # Remove from name mapping if it exists
        new_name_to_address =
          state.name_to_address
          |> Enum.reject(fn {_name, addr} -> addr == address end)
          |> Map.new()

        new_state = %{state | instances: new_instances, name_to_address: new_name_to_address}

        {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call(:list_instances, _from, state) do
    instances = Map.values(state.instances)
    {:reply, instances, state}
  end

  @impl true
  def handle_call(:list_specs, _from, state) do
    specs = Map.values(state.specs)
    {:reply, specs, state}
  end

  @impl true
  def handle_call(:fresh_id, _from, state) do
    id = state.next_id
    new_state = %{state | next_id: id + 1}
    {:reply, id, new_state}
  end

  # Check if a name is already in use
  @spec check_name_conflict(atom() | nil, map()) :: :ok | {:error, atom()}
  defp check_name_conflict(nil, _name_to_address), do: :ok

  defp check_name_conflict(name, name_to_address) do
    case Map.get(name_to_address, name) do
      nil -> :ok
      _existing_address -> {:error, :name_already_taken}
    end
  end
end
