defmodule EngineSystem.Engine.DSL.Utils do
  @moduledoc """
  I provide common utility functions for the Engine DSL system.

  I contain:
  - Type inference utilities
  - Field generation utilities
  - Other common DSL functionality
  """

  @doc """
  I infer the Elixir type from a given value.

  This function analyzes a value and returns the corresponding Elixir type atom.
  Used by various DSL builders to automatically determine field types.

  ## Parameters

  - `value` - The value to analyze

  ## Returns

  An atom representing the inferred type

  ## Examples

      iex> EngineSystem.Engine.DSL.Utils.infer_type(true)
      :boolean

      iex> EngineSystem.Engine.DSL.Utils.infer_type("hello")
      :string

      iex> EngineSystem.Engine.DSL.Utils.infer_type(42)
      :integer
  """
  # Check boolean first!
  def infer_type(value) when is_boolean(value), do: :boolean
  def infer_type(value) when is_function(value), do: :function
  def infer_type(value) when is_atom(value) and value != nil, do: :atom
  def infer_type(value) when is_integer(value), do: :integer
  def infer_type(value) when is_float(value), do: :float
  def infer_type(value) when is_binary(value), do: :string
  def infer_type(value) when is_list(value), do: :list
  def infer_type(value) when is_map(value), do: :map
  def infer_type(_), do: :any

  @doc """
  I generate field definitions from a map by inferring types from values.

  This function analyzes the map structure and creates field definitions automatically,
  eliminating the need for explicit field declarations.

  ## Parameters

  - `field_map` - A map containing field names as keys and default values as values

  ## Returns

  A list of field definitions in the format `{field_name, options}`

  ## Examples

      iex> EngineSystem.Engine.DSL.Utils.generate_fields_from_map(%{port: 8080, enabled: true})
      [{:port, [default: 8080, type: :integer]}, {:enabled, [default: true, type: :boolean]}]
  """
  def generate_fields_from_map(field_map) when is_map(field_map) do
    field_map
    |> Enum.map(fn {key, value} ->
      type = infer_type(value)
      {key, [default: value, type: type]}
    end)
  end

  def generate_fields_from_map(_), do: []
end
