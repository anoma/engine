defmodule EngineSystem.Engine.DSL.InterfaceBuilder do
  @moduledoc """
  I provide macros and functions for building engine message interfaces.

  This module handles the interface Def. part of the DSL, extracted
  from the main DSL module for better separation of concerns.
  """

  @doc """
  I define the message interface for the engine.

  The interface specifies all the message types that the engine can receive
  and process. Each message has a tag (name) and optional field specifications
  that define the expected structure of the message data.

  ## Parameters

  - `block` - Block containing message definitions using the `message/2` macro

  ## Examples

  ```elixir
  # Simple interface with basic messages
  defengine EchoEngine do
    interface do
      message :echo
      message :ping
      message :shutdown
    end
    # ...
  end
  ```

  ```elixir
  # Interface with typed message fields
  defengine KVStoreEngine do
    interface do
      message :get, key: :atom
      message :put, key: :atom, value: :any
      message :delete, key: :atom
      message :list_keys
      message :result, value: {:option, :any}
      message :ack
      message :error, reason: :string
    end
    # ...
  end
  ```

  ```elixir
  # Complex interface with detailed field specifications
  defengine UserManagerEngine do
    interface do
      message :create_user, name: :string, email: :string, role: :atom
      message :update_user, id: :integer, name: {:optional, :string}, email: {:optional, :string}
      message :delete_user, id: :integer
      message :find_user, id: :integer
      message :list_users, filters: {:optional, :map}
      message :user_response, user: :map
      message :user_list, users: {:list, :map}
      message :error, message: :string, code: :integer
    end
    # ...
  end
  ```

  ## Notes

  - The interface is validated at compile time
  - Duplicate message tags will cause compilation errors
  - Field specifications are used for runtime message validation
  - Messages without field specifications accept any payload structure
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

      case EngineSystem.Engine.DSL.InterfaceBuilder.validate_duplicate_tags(all_definitions) do
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

  ## Parameters

  - `tag` - The message tag (atom) that identifies this message type
  - `fields` - Keyword list of field specifications (optional, defaults to [])

  ## Field Types

  Supported field types include:
  - `:atom` - Atom values
  - `:string` - String values
  - `:integer` - Integer values
  - `:float` - Float values
  - `:boolean` - Boolean values
  - `:map` - Map values
  - `:list` - List values
  - `:any` - Any value type
  - `{:optional, type}` - Optional field of the specified type
  - `{:list, type}` - List containing elements of the specified type
  - `{:option, type}` - Either the specified type or nil

  ## Examples

  ```elixir
  # Simple message with no fields
  message :ping

  # Message with typed fields
  message :get, key: :atom

  # Message with multiple fields
  message :create_user, name: :string, email: :string, age: :integer

  # Message with optional fields
  message :update_user,
    id: :integer,
    name: {:optional, :string},
    email: {:optional, :string}

  # Message with complex types
  message :batch_operation,
    items: {:list, :map},
    options: {:optional, :map},
    callback: {:option, :atom}

  # Message for responses
  message :user_created,
    user: :map,
    timestamp: :integer

  # Error message
  message :error,
    message: :string,
    code: :integer,
    details: {:optional, :map}

  # Message with any-type payload
  message :log_event,
    level: :atom,
    data: :any

  # Acknowledgment message
  message :ack
  ```

  ## Validation

  Field specifications are used for:
  - Compile-time interface validation
  - Runtime message validation (when enabled)
  - Documentation and tooling support
  - IDE autocompletion and type hints

  ## Notes

  - Message tags must be unique within an interface
  - Field names must be unique within a message
  - Fields without type specifications default to `:any`
  - Use descriptive message tags for better code readability

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

  ## Parameters

  - `interface` - The interface Def. to validate

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
