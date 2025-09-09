defmodule EngineSystem.Engine.DSL.InterfaceBuilder do
  @moduledoc """
  I provide macros and functions for building engine message interfaces.

  This module handles the interface Def. part of the DSL, extracted
  from the main DSL module for better separation of concerns.
  """

  alias EngineSystem.Engine.DSL.InterfaceBuilder

  @doc """
  I define the message interface for the engine.

  The interface specifies all the message types that the engine can receive
  and process. Each message has a tag (name) and optional field specifications
  that define the expected structure of the message data.
  """
  defmacro interface(do: block) do
    quote do
      # Temporarily store current interface and all message definitions (including duplicates)
      Module.put_attribute(__MODULE__, :current_interface, [])
      Module.put_attribute(__MODULE__, :all_message_definitions, [])
      unquote(block)

      # Validate for duplicates before updating spec
      all_definitions =
        Module.get_attribute(__MODULE__, :all_message_definitions) |> Enum.reverse()

      current_interface = Module.get_attribute(__MODULE__, :current_interface)

      case InterfaceBuilder.validate_duplicate_tags(all_definitions) do
        :ok ->
          :ok

        {:error, duplicate_info} ->
          {tag, first_location, duplicate_location} = duplicate_info

          raise CompileError,
            file: duplicate_location.file,
            line: duplicate_location.line,
            description: """
            duplicate message tag #{inspect(tag)}
                First definition at #{first_location.file}:#{first_location.line}
                Duplicate definition at #{duplicate_location.file}:#{duplicate_location.line}

                Suggestion: Use different tag names like #{inspect(:"#{tag}_by_key")} and #{inspect(:"#{tag}_by_id")}
            """
      end

      # Update spec with collected interface
      spec_data = Module.get_attribute(__MODULE__, :engine_spec_data)
      interface = current_interface |> Enum.reverse()
      updated_spec = %{spec_data | interface: interface}
      Module.put_attribute(__MODULE__, :engine_spec_data, updated_spec)
      Module.delete_attribute(__MODULE__, :current_interface)
      Module.delete_attribute(__MODULE__, :all_message_definitions)
    end
  end

  @doc """
  I define a message type in the interface.

  Each message definition specifies a message tag (name) and optional field
  specifications that describe the expected structure and types of the message data.
  """
  defmacro message(tag, fields \\ []) do
    location = %{
      file: __CALLER__.file,
      line: __CALLER__.line
    }

    quote do
      current_interface = Module.get_attribute(__MODULE__, :current_interface)
      all_definitions = Module.get_attribute(__MODULE__, :all_message_definitions)

      # Add this definition to our tracking list
      Module.put_attribute(__MODULE__, :all_message_definitions, [
        {unquote(tag), unquote(Macro.escape(location))} | all_definitions
      ])

      # Add to interface as well
      Module.put_attribute(__MODULE__, :current_interface, [
        {unquote(tag), unquote(fields)} | current_interface
      ])
    end
  end

  @doc """
  I validate for duplicate message tags and return detailed error information.
  """
  def validate_duplicate_tags(all_definitions) do
    find_first_duplicate(all_definitions, %{})
  end

  # Helper function to find the first duplicate and its locations
  defp find_first_duplicate([], _seen), do: :ok

  defp find_first_duplicate([{tag, location} | rest], seen) do
    case Map.get(seen, tag) do
      nil ->
        find_first_duplicate(rest, Map.put(seen, tag, location))

      first_location ->
        {:error, {tag, first_location, location}}
    end
  end

  @doc """
  I validate a message interface definition.
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
