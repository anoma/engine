defmodule EngineSystem.Engine.DSL.InterfaceBuilder do
  @moduledoc """
  I provide macros and functions for building engine message interfaces.

  This module handles the interface definition part of the DSL, extracted
  from the main DSL module for better separation of concerns.
  """

  @doc """
  I define the message interface for the engine.
  """
  defmacro interface(do: block) do
    quote do
      # Temporarily store current interface
      Module.put_attribute(__MODULE__, :current_interface, [])
      unquote(block)

      # Update spec with collected interface
      spec_data = Module.get_attribute(__MODULE__, :engine_spec_data)
      interface = Module.get_attribute(__MODULE__, :current_interface) |> Enum.reverse()
      updated_spec = %{spec_data | interface: interface}
      Module.put_attribute(__MODULE__, :engine_spec_data, updated_spec)
      Module.delete_attribute(__MODULE__, :current_interface)
    end
  end

  @doc """
  I define a message type in the interface.
  """
  defmacro message(tag, fields \\ []) do
    quote do
      current_interface = Module.get_attribute(__MODULE__, :current_interface)

      Module.put_attribute(__MODULE__, :current_interface, [
        {unquote(tag), unquote(fields)} | current_interface
      ])
    end
  end

  @doc """
  I validate a message interface definition.

  ## Parameters

  - `interface` - The interface definition to validate

  ## Returns

  - `:ok` if valid
  - `{:error, reason}` if invalid
  """
  @spec validate_interface(list()) :: :ok | {:error, String.t()}
  def validate_interface(interface) when is_list(interface) do
    case validate_message_tags(interface) do
      :ok -> validate_message_fields(interface)
      error -> error
    end
  end

  def validate_interface(_), do: {:error, "Interface must be a list"}

  # Private helper functions

  defp validate_message_tags(interface) do
    tags = Enum.map(interface, fn {tag, _fields} -> tag end)
    unique_tags = Enum.uniq(tags)

    if length(tags) == length(unique_tags) do
      :ok
    else
      {:error, "Duplicate message tags found in interface"}
    end
  end

  defp validate_message_fields(interface) do
    Enum.reduce_while(interface, :ok, fn {tag, fields}, _acc ->
      case validate_field_list(fields) do
        :ok -> {:cont, :ok}
        error -> {:halt, {:error, "Invalid fields for message #{tag}: #{elem(error, 1)}"}}
      end
    end)
  end

  defp validate_field_list(fields) when is_list(fields) do
    field_names = Keyword.keys(fields)
    unique_names = Enum.uniq(field_names)

    if length(field_names) == length(unique_names) do
      :ok
    else
      {:error, "Duplicate field names"}
    end
  end

  defp validate_field_list(_), do: {:error, "Fields must be a keyword list"}
end
