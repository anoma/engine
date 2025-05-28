defmodule EngineSystem.Engine.DSL.UtilsTest do
  use ExUnit.Case, async: true

  alias EngineSystem.Engine.DSL.Utils

  describe "infer_type/1" do
    test "infers boolean type correctly" do
      assert Utils.infer_type(true) == :boolean
      assert Utils.infer_type(false) == :boolean
    end

    test "infers atom type correctly" do
      assert Utils.infer_type(:test) == :atom
      assert Utils.infer_type(:production) == :atom
    end

    test "infers integer type correctly" do
      assert Utils.infer_type(42) == :integer
      assert Utils.infer_type(-123) == :integer
      assert Utils.infer_type(0) == :integer
    end

    test "infers float type correctly" do
      assert Utils.infer_type(3.14) == :float
      assert Utils.infer_type(-2.5) == :float
    end

    test "infers string type correctly" do
      assert Utils.infer_type("hello") == :string
      assert Utils.infer_type("") == :string
    end

    test "infers list type correctly" do
      assert Utils.infer_type([1, 2, 3]) == :list
      assert Utils.infer_type([]) == :list
    end

    test "infers map type correctly" do
      assert Utils.infer_type(%{key: :value}) == :map
      assert Utils.infer_type(%{}) == :map
    end

    test "infers any type for nil" do
      assert Utils.infer_type(nil) == :any
    end

    test "infers any type for unknown types" do
      assert Utils.infer_type({:tuple, :value}) == :any
    end
  end

  describe "generate_fields_from_map/1" do
    test "generates field definitions for simple map" do
      map = %{
        port: 8080,
        enabled: true,
        name: "test_engine",
        timeout: 30.5
      }

      expected = [
        {:port, [default: 8080, type: :integer]},
        {:enabled, [default: true, type: :boolean]},
        {:name, [default: "test_engine", type: :string]},
        {:timeout, [default: 30.5, type: :float]}
      ]

      result = Utils.generate_fields_from_map(map)

      # Sort both lists for comparison since map iteration order is not guaranteed
      assert Enum.sort(result) == Enum.sort(expected)
    end

    test "generates field definitions for complex map" do
      map = %{
        config: %{nested: :value},
        items: [1, 2, 3],
        mode: :production,
        count: 0
      }

      result = Utils.generate_fields_from_map(map)

      # Check that all fields are present with correct types
      assert length(result) == 4
      assert {:config, [default: %{nested: :value}, type: :map]} in result
      assert {:items, [default: [1, 2, 3], type: :list]} in result
      assert {:mode, [default: :production, type: :atom]} in result
      assert {:count, [default: 0, type: :integer]} in result
    end

    test "returns empty list for non-map input" do
      assert Utils.generate_fields_from_map("not a map") == []
      assert Utils.generate_fields_from_map(123) == []
      assert Utils.generate_fields_from_map(nil) == []
    end

    test "handles empty map" do
      assert Utils.generate_fields_from_map(%{}) == []
    end
  end
end
