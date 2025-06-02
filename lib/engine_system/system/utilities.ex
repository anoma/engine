defmodule EngineSystem.System.Utilities do
  @moduledoc """
  I provide utility functions for system-level operations.

  This module contains common functionality used across system modules
  to improve code organization and reduce duplication.

  ## Public API

  ### Address Management
  - `generate_address/2` - Generate a unique engine address
  - `validate_address/1` - Validate an engine address format
  - `extract_ids/1` - Extract node and engine IDs from an address
  """

  alias EngineSystem.Engine.Spec
  alias EngineSystem.Engine.State
  alias EngineSystem.System.Message

  @doc """
  I generate a unique address for an engine.

  ## Parameters

  - `node_id` - The node identifier (defaults to 0 for single-node systems)
  - `engine_id` - The engine identifier (optional, will be generated if nil)

  ## Returns

  A unique engine address tuple.
  """
  @spec generate_address(non_neg_integer(), non_neg_integer() | nil) :: State.address()
  def generate_address(node_id \\ 0, engine_id \\ nil) do
    final_engine_id = engine_id || generate_engine_id()
    {node_id, final_engine_id}
  end

  @doc """
  I validate an engine address format.

  ## Parameters

  - `address` - The address to validate

  ## Returns

  - `:ok` if the address is valid
  - `{:error, reason}` if the address is invalid
  """
  @spec validate_address(any()) :: :ok | {:error, String.t()}
  def validate_address({node_id, engine_id})
      when is_integer(node_id) and node_id >= 0 and
             is_integer(engine_id) and engine_id >= 0 do
    :ok
  end

  def validate_address(_), do: {:error, "Invalid address format"}

  @doc """
  I extract node and engine IDs from an address.

  ## Parameters

  - `address` - The address to decompose

  ## Returns

  - `{:ok, {node_id, engine_id}}` if successful
  - `{:error, reason}` if the address is invalid
  """
  @spec decompose_address(State.address()) ::
          {:ok, {non_neg_integer(), non_neg_integer()}} | {:error, String.t()}
  def decompose_address({node_id, engine_id} = address) do
    case validate_address(address) do
      :ok -> {:ok, {node_id, engine_id}}
      error -> error
    end
  end

  @doc """
  I check if two addresses are on the same node.

  ## Parameters

  - `address1` - First address
  - `address2` - Second address

  ## Returns

  - `true` if both addresses are on the same node
  - `false` otherwise
  """
  @spec same_node?(State.address(), State.address()) :: boolean()
  def same_node?({node_id, _}, {node_id, _}), do: true
  def same_node?(_, _), do: false

  @doc """
  I format an address for display purposes.

  ## Parameters

  - `address` - The address to format

  ## Returns

  A formatted string representation of the address.
  """
  @spec format_address(State.address()) :: String.t()
  def format_address({node_id, engine_id}) do
    "#{node_id}:#{engine_id}"
  end

  @doc """
  I parse an address from a string format.

  ## Parameters

  - `address_string` - String in format "node_id:engine_id"

  ## Returns

  - `{:ok, address}` if parsing succeeded
  - `{:error, reason}` if parsing failed
  """
  @spec parse_address(String.t()) :: {:ok, State.address()} | {:error, String.t()}
  def parse_address(address_string) when is_binary(address_string) do
    case String.split(address_string, ":") do
      [node_str, engine_str] ->
        with {node_id, ""} <- Integer.parse(node_str),
             {engine_id, ""} <- Integer.parse(engine_str),
             :ok <- validate_address({node_id, engine_id}) do
          {:ok, {node_id, engine_id}}
        else
          _ -> {:error, "Invalid address format"}
        end

      _ ->
        {:error, "Address must be in format 'node_id:engine_id'"}
    end
  end

  def parse_address(_), do: {:error, "Address must be a string"}

  @doc """
  I generate system-wide statistics.

  ## Parameters

  - `instances` - List of instance information
  - `specs` - List of registered specs

  ## Returns

  A map with system statistics.
  """
  @spec generate_system_stats([any()], [any()]) :: %{
          instances_by_spec: map(),
          running_instances: non_neg_integer(),
          specs_by_version: map(),
          system_uptime: non_neg_integer(),
          total_instances: non_neg_integer(),
          total_specs: non_neg_integer()
        }
  def generate_system_stats(instances, specs) do
    %{
      total_instances: length(instances),
      total_specs: length(specs),
      running_instances: count_running_instances(instances),
      specs_by_version: group_specs_by_version(specs),
      instances_by_spec: group_instances_by_spec(instances),
      system_uptime: get_system_uptime()
    }
  end

  # Private helper functions

  defp generate_engine_id do
    :erlang.unique_integer([:positive])
  end

  defp count_running_instances(instances) do
    Enum.count(instances, fn instance ->
      Map.get(instance, :status) == :running
    end)
  end

  defp group_specs_by_version(specs) do
    Enum.group_by(specs, fn spec -> spec.name end)
    |> Enum.map(fn {name, spec_list} ->
      versions = Enum.map(spec_list, fn spec -> spec.version end)
      {name, versions}
    end)
    |> Map.new()
  end

  defp group_instances_by_spec(instances) do
    Enum.group_by(instances, fn instance ->
      {name, version} = Map.get(instance, :spec_key, {:unknown, "0.0.0"})
      "#{name}:#{version}"
    end)
    |> Enum.map(fn {spec_key, instance_list} ->
      {spec_key, length(instance_list)}
    end)
    |> Map.new()
  end

  defp get_system_uptime do
    {uptime_ms, _} = :erlang.statistics(:wall_clock)
    uptime_ms
  end

  @doc """
  I validate a message against a message interface.

  ## Parameters

  - `message` - The message to validate
  - `interface` - The message interface specification

  ## Returns

  - `:ok` if the message is valid
  - `{:error, reason}` if the message is invalid
  """
  @spec validate_message_interface(Message.t(), Spec.message_interface()) ::
          :ok | {:error, String.t()}
  def validate_message_interface(%Message{payload: payload}, interface) do
    case extract_message_tag(payload) do
      {:ok, tag} -> validate_tag_in_interface(tag, interface)
      error -> error
    end
  end

  @doc """
  I extract the message tag from a payload.

  ## Parameters

  - `payload` - The message payload

  ## Returns

  - `{:ok, tag}` if a tag can be extracted
  - `{:error, reason}` if no tag can be extracted
  """
  @spec extract_message_tag(any()) :: {:ok, atom()} | {:error, String.t()}
  def extract_message_tag({tag, _data}) when is_atom(tag), do: {:ok, tag}
  def extract_message_tag(tag) when is_atom(tag), do: {:ok, tag}
  def extract_message_tag(_), do: {:error, "Cannot extract message tag"}

  @doc """
  I validate that a tag exists in the message interface.

  ## Parameters

  - `tag` - The message tag to validate
  - `interface` - The message interface specification

  ## Returns

  - `:ok` if the tag is valid
  - `{:error, reason}` if the tag is invalid
  """
  @spec validate_tag_in_interface(atom(), Spec.message_interface()) ::
          :ok | {:error, String.t()}
  def validate_tag_in_interface(tag, interface) do
    interface_tags = Enum.map(interface, fn {interface_tag, _fields} -> interface_tag end)

    if tag in interface_tags do
      :ok
    else
      {:error, "Message tag #{tag} not found in interface"}
    end
  end

  @doc """
  I apply a message filter to determine if a message should be processed.

  ## Parameters

  - `message` - The message to filter
  - `filter_func` - The filter function
  - `config` - Engine configuration (optional)
  - `env` - Engine environment (optional)

  ## Returns

  - `true` if the message should be processed
  - `false` if the message should be filtered out
  """
  @spec apply_message_filter(Message.t(), function(), any(), any()) :: boolean()
  def apply_message_filter(message, filter_func, config \\ nil, env \\ nil) do
    case :erlang.fun_info(filter_func, :arity) do
      {:arity, 1} -> filter_func.(message)
      {:arity, 3} -> filter_func.(message, config, env)
      {:arity, 4} -> filter_func.(message, config, env, nil)
      # Default to accepting if arity doesn't match
      _ -> true
    end
  rescue
    # Default to accepting if filter fails
    _ -> true
  end
end
