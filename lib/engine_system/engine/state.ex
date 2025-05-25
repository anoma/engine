defmodule EngineSystem.Engine.State do
  @moduledoc """
  Engine state components following the formal paper specifications.

  This module implements the core state structures from "ART-Mailboxes-actors/main.tex":

  ## Paper References

  - **Def. 2.6 (Engine Configuration)**: Configuration tuple ⟨r, mode, c⟩
  - **Def. 2.7 (Engine Environment)**: Environment tuple ⟨s, m⟩
  - **Def. 2.5 (Engine Lifecycle)**: Status with ready/busy/terminated states

  These structures represent an engine's configuration, environment, and status
  as defined in the formal model, providing the runtime state management for
  engine instances.

  ## Public API

  This module provides three main submodules with their own APIs:

  ### Configuration (State.Configuration)
  - `new/3` - Create a new engine configuration
  - `process?/1` - Check if this is a processing engine configuration
  - `mailbox?/1` - Check if this is a mailbox engine configuration

  ### Environment (State.Environment)
  - `new/2` - Create a new engine environment
  - `add_address/3` - Add an address to the address book
  - `lookup_address/2` - Look up an address by name
  - `update_local_state/2` - Update the local state

  ### Status (State.Status)
  - `ready/1` - Create a ready status with message filter
  - `busy/0` - Create a busy status
  - `terminated/0` - Create a terminated status
  - `ready?/1` - Check if status is ready
  - `busy?/1` - Check if status is busy
  - `terminated?/1` - Check if status is terminated
  """

  @type address :: {node_id :: non_neg_integer(), engine_id :: non_neg_integer()}
  @type engine_mode :: :process | :mail

  defmodule Configuration do
    @moduledoc """
    Engine configuration following Def. 2.6 from the formal paper.

    Implements the configuration tuple ⟨r, mode, c⟩ where:
    - `parent`: r (Option(Address) - optional parent reference)
    - `mode`: operational mode (:process | :mail from Equation 2.5)
    - `engine_specific`: c (engine-specific configuration data)

    **Paper Reference**: Def. 2.6, Equation (2.6)
    """
    use TypedStruct

    alias EngineSystem.Engine.State

    typedstruct do
      @typedoc """
      I define the structure for engine configuration.

      ### Fields

      - `:parent` - Optional reference (address) of the engine's parent. Enforced: false.
      - `:mode` - The engine's operational mode (:process or :mail). Enforced: true.
      - `:engine_specific` - Configuration data specific to the engine type. Enforced: false.
      """
      field(:parent, State.address() | nil, enforce: false)
      field(:mode, State.engine_mode(), enforce: true)
      field(:engine_specific, any(), enforce: false)
    end

    @doc """
    I create a new engine configuration.

    ## Parameters

    - `parent` - Optional reference (address) of the engine's parent
    - `mode` - The engine's operational mode (:process or :mail)
    - `engine_specific` - Configuration data specific to the engine type

    ## Returns

    A new Configuration struct.
    """
    @spec new(State.address() | nil, State.engine_mode(), any()) :: t()
    def new(parent, mode, engine_specific) do
      %__MODULE__{
        parent: parent,
        mode: mode,
        engine_specific: engine_specific
      }
    end

    @doc """
    I check if this is a processing engine configuration.
    """
    @spec process?(t()) :: boolean()
    def process?(%__MODULE__{mode: :process}), do: true
    def process?(_), do: false

    @doc """
    I check if this is a mailbox engine configuration.
    """
    @spec mailbox?(t()) :: boolean()
    def mailbox?(%__MODULE__{mode: :mail}), do: true
    def mailbox?(_), do: false
  end

  defmodule Environment do
    @moduledoc """
    Engine environment following Def. 2.7 from the formal paper.

    Implements the environment tuple ⟨s, m⟩ where:
    - `local_state`: s (L - engine's local state)
    - `address_book`: m (Name → Address mapping including :self)

    **Paper Reference**: Def. 2.7, Equation (2.7)
    """
    use TypedStruct

    alias EngineSystem.Engine.State

    @type name :: atom() | String.t()
    @type address_book :: %{name() => State.address()}

    typedstruct do
      @typedoc """
      I define the structure for engine environment.

      ### Fields

      - `:local_state` - The engine-specific local state. Enforced: false.
      - `:address_book` - The engine's address book (Name → Address mapping). Enforced: false.
      """
      field(:local_state, any(), enforce: false)
      field(:address_book, address_book(), enforce: false, default: %{})
    end

    @doc """
    I create a new engine environment.

    ## Parameters

    - `local_state` - The engine-specific local state
    - `address_book` - The engine's address book (defaults to empty)

    ## Returns

    A new Environment struct.
    """
    @spec new(any(), address_book()) :: t()
    def new(local_state, address_book \\ %{}) do
      %__MODULE__{
        local_state: local_state,
        address_book: address_book
      }
    end

    @doc """
    I add an address to the address book.

    ## Parameters

    - `env` - The environment
    - `name` - The name to associate with the address
    - `address` - The address to add

    ## Returns

    Updated environment with the new address.
    """
    @spec add_address(t(), name(), State.address()) :: t()
    def add_address(%__MODULE__{} = env, name, address) do
      %{env | address_book: Map.put(env.address_book, name, address)}
    end

    @doc """
    I look up an address by name.

    ## Parameters

    - `env` - The environment
    - `name` - The name to look up

    ## Returns

    - `{:ok, address}` if found
    - `:not_found` if not found
    """
    @spec lookup_address(t(), name()) :: {:ok, State.address()} | :not_found
    def lookup_address(%__MODULE__{address_book: address_book}, name) do
      Map.get(address_book, name) |> handle_address_lookup()
    end

    defp handle_address_lookup(nil), do: :not_found
    defp handle_address_lookup(address), do: {:ok, address}

    @doc """
    I update the local state.

    ## Parameters

    - `env` - The environment
    - `new_state` - The new local state

    ## Returns

    Updated environment with the new local state.
    """
    @spec update_local_state(t(), any()) :: t()
    def update_local_state(%__MODULE__{} = env, new_state) do
      %{env | local_state: new_state}
    end
  end

  defmodule Status do
    @moduledoc """
    Engine status following Def. 2.5 from the formal paper.

    Implements the engine lifecycle with states from Equation (2.5):
    - `ready(f)`: engine can accept messages (with filter predicate f: M → Bool)
    - `busy(m)`: engine is processing message m
    - `terminated`: engine has stopped processing

    Corresponds to Figure 2 in the paper showing state transitions:
    ready(f) ⟷ busy(m) → terminated

    **Paper Reference**: Def. 2.5, Equation (2.5), Figure 2
    """
    @type message_filter :: function()
    @type message :: any()

    @type t ::
            {:ready, message_filter()}
            | {:busy, message()}
            | :terminated

    @doc """
    I create a ready status with a message filter.

    ## Parameters

    - `filter` - The message filter function

    ## Returns

    A ready status tuple.
    """
    @spec ready(message_filter()) :: t()
    def ready(filter) do
      {:ready, filter}
    end

    @doc """
    I create a busy status with the current message.

    ## Parameters

    - `message` - The message being processed

    ## Returns

    A busy status tuple.
    """
    @spec busy(message()) :: t()
    def busy(message) do
      {:busy, message}
    end

    @doc """
    I create a terminated status.

    ## Returns

    A terminated status atom.
    """
    @spec terminated() :: t()
    def terminated do
      :terminated
    end

    @doc """
    I check if the status is ready.

    ## Parameters

    - `status` - The status to check

    ## Returns

    `true` if ready, `false` otherwise.
    """
    @spec ready?(t()) :: boolean()
    def ready?({:ready, _}), do: true
    def ready?(_), do: false

    @doc """
    I check if the status is busy.

    ## Parameters

    - `status` - The status to check

    ## Returns

    `true` if busy, `false` otherwise.
    """
    @spec busy?(t()) :: boolean()
    def busy?({:busy, _}), do: true
    def busy?(_), do: false

    @doc """
    I check if the status is terminated.

    ## Parameters

    - `status` - The status to check

    ## Returns

    `true` if terminated, `false` otherwise.
    """
    @spec terminated?(t()) :: boolean()
    def terminated?(:terminated), do: true
    def terminated?(_), do: false

    @doc """
    I get the message filter from a ready status.

    ## Parameters

    - `status` - The status (must be ready)

    ## Returns

    - `{:ok, filter}` if ready
    - `:not_ready` if not ready
    """
    @spec get_filter(t()) :: {:ok, message_filter()} | :not_ready
    def get_filter({:ready, filter}), do: {:ok, filter}
    def get_filter(_), do: :not_ready

    @doc """
    I get the current message from a busy status.

    ## Parameters

    - `status` - The status (must be busy)

    ## Returns

    - `{:ok, message}` if busy
    - `:not_busy` if not busy
    """
    @spec get_current_message(t()) :: {:ok, message()} | :not_busy
    def get_current_message({:busy, message}), do: {:ok, message}
    def get_current_message(_), do: :not_busy
  end
end
