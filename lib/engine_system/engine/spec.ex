defmodule EngineSystem.Engine.Spec do
  @moduledoc """
  I provide a struct that represents the static type information for an engine,
  corresponding to the formal model.

  ## Paper References

  - **Def. 2.15 (Engine)**: Engine type structure
  - **Def. 2.3 (Message Interface)**: Message interface specification
  - **Def. 2.6 (Engine Configuration)**: Configuration type specification
  - **Def. 2.7 (Engine Environment)**: Environment type specification
  - **Def. 2.14 (Engine Behaviour)**: Behaviour specification

  ## Components

  - `interface`: MsgType_i (message interface from §2.3)
  - `behaviour_rules`: BehaviourType_i (guarded actions from §2.14)
  - `config_spec`: Configuration type specification (Def. 2.6)
  - `env_spec`: Environment type specification (Def. 2.7)
  - `message_filter`: Message filter predicate (Def. 2.5)

  This represents the persistent EngineSpec from the formal model.

  ## Public API

  ### Spec Creation
  - `new/2` - Create a new EngineSpec with sensible defaults
  - `new/7` - Create a new EngineSpec with all parameters explicitly provided

  ### Validation
  - `validate_message/2` - Validate that a message conforms to this engine's interface

  ### Configuration Access
  - `default_config/1` - Get the default configuration for this engine type
  - `default_environment/1` - Get the default environment for this engine type
  - `get_message_filter/1` - Get the message filter function for this engine type

  ### Interface Utilities
  - `has_message?/2` - Check if this engine supports a specific message tag
  - `get_message_fields/2` - Get the field specification for a message tag
  - `get_message_tags/1` - Get all message tags supported by this engine
  """

  @type message_tag :: atom()
  @type message_fields :: keyword()
  @type message_interface :: [{message_tag(), message_fields()}]

  @type config_spec :: %{
          name: atom(),
          default: any(),
          fields: keyword()
        }

  @type env_spec :: %{
          name: atom(),
          default: any(),
          fields: keyword()
        }

  @type behaviour_rule :: {message_tag(), any()}
  @type behaviour_rules :: [behaviour_rule()]

  @type message_filter :: {:default_filter, []} | {:custom_filter, any()}

  use TypedStruct

  # Default values
  @default_config_spec %{
    name: :default_config,
    default: %{},
    fields: []
  }

  @default_env_spec %{
    name: :default_env,
    default: %{},
    fields: []
  }

  @default_interface [
    {:init, []},
    {:terminate, []},
    {:ping, []},
    {:pong, []}
  ]

  @default_behaviour_rules [
    {:init, :noop},
    {:terminate, :noop},
    {:ping, :pong},
    {:pong, :noop}
  ]

  @default_message_filter {:default_filter, []}

  typedstruct do
    @typedoc """
    I define the structure for an engine specification.

    ### Fields

    - `:name` - The engine type name. Enforced: true.
    - `:version` - The engine type version. Enforced: true.
    - `:interface` - The message interface definition. Enforced: true.
    - `:config_spec` - The configuration specification. Enforced: true.
    - `:env_spec` - The environment specification. Enforced: true.
    - `:behaviour_rules` - The behaviour rules. Enforced: true.
    - `:message_filter` - The message filter function. Enforced: true.
    - `:mode` - The engine mode: `:process` or `:mailbox`. Enforced: false, default: `:process`.
    - `:producer_config` - GenStage producer configuration for mailbox engines. Enforced: false.
    """
    field(:name, atom(), enforce: true)
    field(:version, String.t(), enforce: true)
    field(:interface, message_interface(), enforce: true)
    field(:config_spec, config_spec(), enforce: true)
    field(:env_spec, env_spec(), enforce: true)
    field(:behaviour_rules, behaviour_rules(), enforce: true)
    field(:message_filter, message_filter(), enforce: true)
    field(:mode, atom(), enforce: false)
  end

  @doc """
  I create a new EngineSpec with sensible defaults and only required name.

  ## Parameters

  - `name` - The engine type name
  - `opts` - Optional keyword list with overrides:
    - `:version` - Engine version (default: "1.0.0")
    - `:interface` - Message interface (default: basic ping/pong interface)
    - `:config_spec` - Configuration spec (default: empty config)
    - `:env_spec` - Environment spec (default: empty environment)
    - `:behaviour_rules` - Behaviour rules (default: basic ping/pong rules)
    - `:message_filter` - Message filter (default: accept all)

  ## Returns

  A new EngineSpec struct with sensible defaults.

  ## Examples

      iex> EngineSystem.Engine.Spec.new(:my_engine)
      %EngineSystem.Engine.Spec{name: :my_engine, version: "1.0.0", ...}
  """
  @spec new(atom(), keyword()) :: t()
  def new(name, opts \\ []) do
    %__MODULE__{
      name: name,
      version: Keyword.get(opts, :version, "1.0.0"),
      interface: Keyword.get(opts, :interface, @default_interface),
      config_spec: Keyword.get(opts, :config_spec, @default_config_spec),
      env_spec: Keyword.get(opts, :env_spec, @default_env_spec),
      behaviour_rules: Keyword.get(opts, :behaviour_rules, @default_behaviour_rules),
      message_filter: Keyword.get(opts, :message_filter, @default_message_filter)
    }
  end

  @doc """
  I create a new EngineSpec with all parameters explicitly provided.

  ## Parameters

  - `name` - The engine type name
  - `version` - The engine type version
  - `interface` - The message interface definition
  - `config_spec` - The configuration specification
  - `env_spec` - The environment specification
  - `behaviour_rules` - The behaviour rules
  - `message_filter` - The message filter function

  ## Returns

  A new EngineSpec struct.
  """
  @spec new(
          atom(),
          String.t(),
          message_interface(),
          config_spec(),
          env_spec(),
          behaviour_rules(),
          message_filter()
        ) :: t()
  def new(name, version, interface, config_spec, env_spec, behaviour_rules, message_filter) do
    %__MODULE__{
      name: name,
      version: version,
      interface: interface,
      config_spec: config_spec,
      env_spec: env_spec,
      behaviour_rules: behaviour_rules,
      message_filter: message_filter
    }
  end

  @doc """
  I validate that a message conforms to this engine's interface.

  ## Parameters

  - `spec` - The engine specification
  - `message` - The message to validate as `{tag, payload}`

  ## Returns

  - `:ok` if the message is valid
  - `{:error, reason}` if the message is invalid
  """
  @spec validate_message(t(), {message_tag(), any()}) :: :ok | {:error, any()}
  def validate_message(%__MODULE__{interface: interface}, {tag, _payload}) do
    case Enum.find(interface, fn {msg_tag, _fields} -> msg_tag == tag end) do
      nil -> {:error, {:unknown_message_tag, tag}}
      # For now, just check tag exists
      {^tag, _fields} -> :ok
    end
  end

  @doc """
  I get the default configuration for this engine type.

  ## Parameters

  - `spec` - The engine specification

  ## Returns

  The default configuration value.
  """
  @spec default_config(t()) :: any()
  def default_config(%__MODULE__{config_spec: config_spec}) do
    config_spec.default
  end

  @doc """
  I get the default environment for this engine type.

  ## Parameters

  - `spec` - The engine specification

  ## Returns

  The default environment value.
  """
  @spec default_environment(t()) :: any()
  def default_environment(%__MODULE__{env_spec: env_spec}) do
    env_spec.default
  end

  @doc """
  I get the message filter function for this engine type.

  ## Parameters

  - `spec` - The engine specification

  ## Returns

  The message filter function.
  """
  @spec get_message_filter(t()) :: function()
  def get_message_filter(%__MODULE__{message_filter: {:default_filter, []}}) do
    fn _msg, _config, _env -> true end
  end

  def get_message_filter(%__MODULE__{message_filter: {:custom_filter, _filter_ast}}) do
    # For now, return a default filter. In a full implementation,
    # we would compile the AST to a function
    fn _msg, _config, _env -> true end
  end

  @doc """
  I find a behaviour rule for the given message tag.

  ## Parameters

  - `spec` - The engine specification
  - `tag` - The message tag to find a rule for

  ## Returns

  - `{:ok, rule}` if a rule is found
  - `:not_found` if no rule is found
  """
  @spec find_behaviour_rule(t(), message_tag()) :: {:ok, behaviour_rule()} | :not_found
  def find_behaviour_rule(%__MODULE__{behaviour_rules: rules}, tag) do
    case Enum.find(rules, fn {rule_tag, _action} -> rule_tag == tag end) do
      nil -> :not_found
      rule -> {:ok, rule}
    end
  end

  @doc """
  I get a unique identifier for this engine spec.

  ## Parameters

  - `spec` - The engine specification

  ## Returns

  A unique identifier string.
  """
  @spec spec_id(t()) :: String.t()
  def spec_id(%__MODULE__{name: name, version: version}) do
    "#{name}@#{version}"
  end

  @doc """
  I check if an interface contains a specific message tag.

  ## Parameters

  - `spec` - The engine specification
  - `tag` - Message tag to check

  ## Returns

  `true` if tag exists, `false` otherwise

  ## Examples

      iex> spec = EngineSystem.Engine.Spec.new(:my_engine)
      iex> EngineSystem.Engine.Spec.has_message?(spec, :ping)
      true
      iex> EngineSystem.Engine.Spec.has_message?(spec, :unknown)
      false
  """
  @spec has_message?(t(), message_tag()) :: boolean()
  def has_message?(%__MODULE__{interface: interface}, tag) do
    Enum.any?(interface, fn {msg_tag, _fields} -> msg_tag == tag end)
  end

  @doc """
  I get the field specification for a message tag.

  ## Parameters

  - `spec` - The engine specification
  - `tag` - Message tag to find

  ## Returns

  - `{:ok, fields}` if found
  - `{:error, :not_found}` if not found

  ## Examples

      iex> spec = EngineSystem.Engine.Spec.new(:my_engine)
      iex> EngineSystem.Engine.Spec.get_message_fields(spec, :ping)
      {:ok, []}
      iex> EngineSystem.Engine.Spec.get_message_fields(spec, :unknown)
      {:error, :not_found}
  """
  @spec get_message_fields(t(), message_tag()) :: {:ok, message_fields()} | {:error, :not_found}
  def get_message_fields(%__MODULE__{interface: interface}, tag) do
    case Enum.find(interface, fn {msg_tag, _fields} -> msg_tag == tag end) do
      {^tag, fields} -> {:ok, fields}
      nil -> {:error, :not_found}
    end
  end

  @doc """
  I get all message tags supported by this engine specification.

  ## Parameters

  - `spec` - The engine specification

  ## Returns

  A list of message tags (atoms) that this engine supports.

  ## Examples

      iex> spec = EngineSystem.Engine.Spec.new(:my_engine)
      iex> EngineSystem.Engine.Spec.get_message_tags(spec)
      [:init, :terminate, :ping, :pong]
  """
  @spec get_message_tags(t()) :: [message_tag()]
  def get_message_tags(%__MODULE__{interface: interface}) do
    Enum.map(interface, fn {tag, _fields} -> tag end)
  end
end
