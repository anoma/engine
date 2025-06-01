defmodule EngineSystem.Engine.DSL.Validation do
  @moduledoc """
  I handle validation for DSL components.

  I manage:
  - Engine specification validation
  - Interface validation
  - Message filter validation
  - Cross-component validation

  For interface utility functions, use `EngineSystem.Engine.Spec` or `EngineSystem.API`.
  """

  alias EngineSystem.Engine.DSL.{BehaviorBuilder, ConfigBuilder, EnvironmentBuilder}

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
         :ok <- EnvironmentBuilder.validate_env_spec(spec.env_spec),
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

  def validate_interface(_interface), do: {:error, :invalid_interface}

  defp validate_interface_messages([]), do: :ok

  defp validate_interface_messages([{tag, fields} | rest])
       when is_atom(tag) and is_list(fields) do
    case validate_message_fields(fields) do
      :ok ->
        validate_interface_messages(rest)

      error ->
        error
    end
  end

  defp validate_interface_messages(_invalid), do: {:error, :invalid_message_definition}

  defp validate_message_fields([]), do: :ok

  # Handle keyword list format: [key: :atom, value: :string]
  defp validate_message_fields([{field_name, field_type} | rest])
       when is_atom(field_name) do
    case validate_field_type(field_type) do
      :ok ->
        validate_message_fields(rest)

      error ->
        error
    end
  end

  # Handle simple atom list format: [:key, :value]
  defp validate_message_fields([field_name | rest])
       when is_atom(field_name) do
    validate_message_fields(rest)
  end

  defp validate_message_fields(_invalid), do: {:error, :invalid_message_field}

  defp validate_field_type(type) when is_atom(type), do: :ok
  defp validate_field_type({:option, inner_type}), do: validate_field_type(inner_type)

  defp validate_field_type(field_list) when is_list(field_list) do
    if Enum.all?(field_list, &is_atom/1) do
      :ok
    else
      {:error, :invalid_field_type}
    end
  end

  defp validate_field_type(_invalid_type), do: {:error, :invalid_field_type}

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
end
