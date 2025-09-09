defmodule EngineSystem.Engine.State do
  @moduledoc """
  I provide engine state components including configuration, environment, and status management.
  """

  @type address :: {node_id :: non_neg_integer(), engine_id :: non_neg_integer()}
  @type engine_mode :: :process | :mail

  defmodule Configuration do
    @moduledoc """
    I define engine configuration with parent reference, operational mode, and engine-specific data.
    """
    use TypedStruct

    alias EngineSystem.Engine.State

    typedstruct do
      @typedoc """
      I define the structure for engine configuration.
      """
      field(:parent, State.address() | nil, enforce: false)
      field(:mode, State.engine_mode(), enforce: true)
      field(:engine_specific, any(), enforce: false)
    end

    @doc """
    I create a new engine configuration.
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
    I check if this is a processing engine.
    """
    @spec process?(t()) :: boolean()
    def process?(%__MODULE__{mode: :process}), do: true
    def process?(_), do: false

    @doc """
    I check if this is a mailbox engine.
    """
    @spec mailbox?(t()) :: boolean()
    def mailbox?(%__MODULE__{mode: :mail}), do: true
    def mailbox?(_), do: false
  end

  defmodule Environment do
    @moduledoc """
    I define engine environment with local state and address book management.
    """
    use TypedStruct

    alias EngineSystem.Engine.State

    @type name :: atom() | String.t()
    @type address_book :: %{name() => State.address()}

    typedstruct do
      @typedoc """
      I define the structure for engine environment.
      """
      field(:local_state, any(), enforce: false)
      field(:address_book, address_book(), enforce: false, default: %{})
    end

    @doc """
    I create a new engine environment.
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
    """
    @spec add_address(t(), name(), State.address()) :: t()
    def add_address(%__MODULE__{} = env, name, address) do
      %{env | address_book: Map.put(env.address_book, name, address)}
    end

    @doc """
    I look up an address by name.
    """
    @spec lookup_address(t(), name()) :: {:ok, State.address()} | :not_found
    def lookup_address(%__MODULE__{address_book: address_book}, name) do
      Map.get(address_book, name) |> handle_address_lookup()
    end

    defp handle_address_lookup(nil), do: :not_found
    defp handle_address_lookup(address), do: {:ok, address}

    @doc """
    I update the local state.
    """
    @spec update_local_state(t(), any()) :: t()
    def update_local_state(%__MODULE__{} = env, new_state) do
      %{env | local_state: new_state}
    end
  end

  defmodule Status do
    @moduledoc """
    I define engine lifecycle status with ready, busy, and terminated states.
    """
    @type message_filter :: function()
    @type message :: any()

    @type t ::
            {:ready, message_filter()}
            | {:busy, message()}
            | :terminated

    @doc """
    I create a ready status with filter.
    """
    @spec ready(message_filter()) :: {:ready, message_filter()}
    def ready(filter) do
      {:ready, filter}
    end

    @doc """
    I create a busy status with message.
    """
    @spec busy(message()) :: {:busy, message()}
    def busy(message) do
      {:busy, message}
    end

    @doc """
    I create a terminated status.
    """
    @spec terminated() :: :terminated
    def terminated do
      :terminated
    end

    @doc """
    I check if the status is ready.
    """
    @spec ready?(t()) :: boolean()
    def ready?({:ready, _}), do: true
    def ready?(_), do: false

    @doc """
    I check if the status is busy.
    """
    @spec busy?(t()) :: boolean()
    def busy?({:busy, _}), do: true
    def busy?(_), do: false

    @doc """
    I check if the status is terminated.
    """
    @spec terminated?(t()) :: boolean()
    def terminated?(:terminated), do: true
    def terminated?(_), do: false

    @doc """
    I get the filter from ready status.
    """
    @spec get_filter(t()) :: {:ok, message_filter()} | :not_ready
    def get_filter({:ready, filter}), do: {:ok, filter}
    def get_filter(_), do: :not_ready

    @doc """
    I get the message from busy status.
    """
    @spec get_current_message(t()) :: {:ok, message()} | :not_busy
    def get_current_message({:busy, message}), do: {:ok, message}
    def get_current_message(_), do: :not_busy
  end
end
