defmodule EngineSystem.Engine.Spec do
  @moduledoc """
  I represent static type information for an engine specification, including interface, behavior, and configuration details.
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
  I create a new EngineSpec with defaults.
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
  I create a new EngineSpec with explicit parameters.
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
  I validate a message against the engine interface.
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
  I get the engine's default configuration.
  """
  @spec default_config(t()) :: any()
  def default_config(%__MODULE__{config_spec: config_spec}) do
    config_spec.default
  end

  @doc """
  I get the engine's default environment.
  """
  @spec default_environment(t()) :: any()
  def default_environment(%__MODULE__{env_spec: env_spec}) do
    env_spec.default
  end

  @doc """
  I get the engine's message filter function.
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
  I find a behavior rule for the message tag.
  """
  @spec find_behaviour_rule(t(), message_tag()) :: {:ok, behaviour_rule()} | :not_found
  def find_behaviour_rule(%__MODULE__{behaviour_rules: rules}, tag) do
    case Enum.find(rules, fn {rule_tag, _action} -> rule_tag == tag end) do
      nil -> :not_found
      rule -> {:ok, rule}
    end
  end

  @doc """
  I get the engine spec's unique identifier.
  """
  @spec spec_id(t()) :: String.t()
  def spec_id(%__MODULE__{name: name, version: version}) do
    "#{name}@#{version}"
  end

  @doc """
  I check if the interface has a message tag.
  """
  @spec has_message?(t(), message_tag()) :: boolean()
  def has_message?(%__MODULE__{interface: interface}, tag) do
    Enum.any?(interface, fn {msg_tag, _fields} -> msg_tag == tag end)
  end

  @doc """
  I get the field specification for a message.
  """
  @spec get_message_fields(t(), message_tag()) :: {:ok, message_fields()} | {:error, :not_found}
  def get_message_fields(%__MODULE__{interface: interface}, tag) do
    case Enum.find(interface, fn {msg_tag, _fields} -> msg_tag == tag end) do
      {^tag, fields} -> {:ok, fields}
      nil -> {:error, :not_found}
    end
  end

  @doc """
  I get all message tags in the specification.
  """
  @spec get_message_tags(t()) :: [message_tag()]
  def get_message_tags(%__MODULE__{interface: interface}) do
    Enum.map(interface, fn {tag, _fields} -> tag end)
  end
end
