defmodule EngineSystem.Engine.DSL.Validation do
  @moduledoc """
  I handle validation for DSL components.

  I manage:
  - Engine specification validation
  - Interface validation
  - Message filter validation
  - Cross-component validation
  """

  alias EngineSystem.Engine.DSL.{BehaviorBuilder, ConfigBuilder}

  @doc """
  I validate a complete engine specification.

  ## Parameters

  - `spec` - The engine specification to validate

  ## Returns

  - `:ok` if valid
  - `{:error, reason}` if invalid
  """
  @spec validate_engine_spec(map()) :: :ok | {:error, any()}
  def validate_engine_spec(spec) do
    with :ok <- validate_basic_fields(spec),
         :ok <- validate_interface(spec.interface),
         :ok <- ConfigBuilder.validate_config_spec(spec.config_spec),
         :ok <- validate_env_spec(spec.env_spec),
         :ok <- BehaviorBuilder.validate_behaviour_rules(spec.behaviour_rules),
         :ok <- validate_message_filter(spec.message_filter) do
      validate_cross_references(spec)
    end
  end

  defp validate_basic_fields(%{name: name, version: version})
       when is_atom(name) and is_binary(version) do
    :ok
  end

  defp validate_basic_fields(_), do: {:error, :invalid_basic_fields}

  @doc """
  I validate an interface specification.

  ## Parameters

  - `interface` - The interface to validate

  ## Returns

  - `:ok` if valid
  - `{:error, reason}` if invalid
  """
  @spec validate_interface(list()) :: :ok | {:error, any()}
  def validate_interface(interface) when is_list(interface) do
    validate_interface_messages(interface)
  end

  def validate_interface(_), do: {:error, :invalid_interface}

  defp validate_interface_messages([]), do: :ok

  defp validate_interface_messages([{tag, fields} | rest])
       when is_atom(tag) and is_list(fields) do
    case validate_message_fields(fields) do
      :ok -> validate_interface_messages(rest)
      error -> error
    end
  end

  defp validate_interface_messages(_), do: {:error, :invalid_message_definition}

  defp validate_message_fields([]), do: :ok

  defp validate_message_fields([{field_name, field_type} | rest])
       when is_atom(field_name) do
    case validate_field_type(field_type) do
      :ok -> validate_message_fields(rest)
      error -> error
    end
  end

  defp validate_message_fields(_), do: {:error, :invalid_message_field}

  defp validate_field_type(type) when is_atom(type), do: :ok
  defp validate_field_type({:option, inner_type}), do: validate_field_type(inner_type)
  defp validate_field_type(_), do: {:error, :invalid_field_type}

  defp validate_env_spec(%{name: name, default: _default, fields: fields})
       when is_atom(name) and is_list(fields) do
    validate_env_fields(fields)
  end

  defp validate_env_spec(_), do: {:error, :invalid_env_spec}

  defp validate_env_fields([]), do: :ok

  defp validate_env_fields([{field_name, options} | rest]) when is_atom(field_name) do
    case validate_env_field_options(options) do
      :ok -> validate_env_fields(rest)
      error -> error
    end
  end

  defp validate_env_fields(_), do: {:error, :invalid_env_field_definition}

  defp validate_env_field_options(options) when is_list(options), do: :ok
  defp validate_env_field_options(_), do: {:error, :invalid_env_field_options}

  @doc """
  I validate a message filter specification.

  ## Parameters

  - `message_filter` - The message filter to validate

  ## Returns

  - `:ok` if valid
  - `{:error, reason}` if invalid
  """
  @spec validate_message_filter(any()) :: :ok | {:error, :invalid_message_filter}
  def validate_message_filter({:default_filter, []}), do: :ok
  def validate_message_filter({:custom_filter, _filter_ast}), do: :ok
  def validate_message_filter(_), do: {:error, :invalid_message_filter}

  defp validate_cross_references(spec) do
    # Check that all message handlers have corresponding interface messages
    interface_tags = Enum.map(spec.interface, fn {tag, _fields} -> tag end)
    handler_tags = Enum.map(spec.behaviour_rules, fn {tag, _handler} -> tag end)

    undefined_handlers = handler_tags -- interface_tags

    case undefined_handlers do
      [] -> :ok
      tags -> {:error, {:undefined_message_handlers, tags}}
    end
  end

  @doc """
  I check if an interface contains a specific message tag.

  ## Parameters

  - `tag` - Message tag to check
  - `interface` - Interface specification

  ## Returns

  `true` if tag exists, `false` otherwise
  """
  @spec has_message?(atom(), list()) :: boolean()
  def has_message?(tag, interface) do
    Enum.any?(interface, fn {msg_tag, _fields} -> msg_tag == tag end)
  end

  @doc """
  I get the field specification for a message tag.

  ## Parameters

  - `tag` - Message tag to find
  - `interface` - Interface specification

  ## Returns

  - `{:ok, fields}` if found
  - `{:error, :not_found}` if not found
  """
  @spec get_message_fields(atom(), list()) :: {:ok, list()} | {:error, :not_found}
  def get_message_fields(tag, interface) do
    case Enum.find(interface, fn {msg_tag, _fields} -> msg_tag == tag end) do
      {^tag, fields} -> {:ok, fields}
      nil -> {:error, :not_found}
    end
  end
end
