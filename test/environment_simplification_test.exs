defmodule EngineSystem.EnvironmentSimplificationTest do
  use ExUnit.Case, async: true
  doctest EngineSystem.Engine.DSL.EnvironmentBuilder

  describe "Environment Simplification" do
    test "EnvironmentBuilder validation functions work" do
      alias EngineSystem.Engine.DSL.EnvironmentBuilder

      # Valid environment spec
      valid_spec = %{
        name: :test_env,
        default: %{counter: 0},
        fields: [{:counter, [default: 0, type: :integer]}]
      }

      assert EnvironmentBuilder.validate_env_spec(valid_spec) == :ok

      # Invalid environment spec - missing name
      invalid_spec = %{
        default: %{counter: 0},
        fields: []
      }

      assert EnvironmentBuilder.validate_env_spec(invalid_spec) == {:error, :invalid_env_spec}

      # Invalid field definition
      invalid_fields = %{
        name: :test_env,
        default: %{},
        # field name should be atom
        fields: [{"not_atom", []}]
      }

      assert EnvironmentBuilder.validate_env_spec(invalid_fields) ==
               {:error, :invalid_field_definition}
    end

    test "generate_fields_from_map function works correctly" do
      alias EngineSystem.Engine.DSL.EnvironmentBuilder

      env_map = %{
        counter: 100,
        enabled: false,
        name: "test",
        data: %{key: "value"},
        items: [1, 2, 3],
        rate: 3.14,
        atom_val: :test,
        nil_val: nil
      }

      fields = EnvironmentBuilder.generate_fields_from_map(env_map)

      # Should generate correct field definitions
      assert length(fields) == 8

      fields_map = Map.new(fields)
      assert fields_map[:counter] == [default: 100, type: :integer]
      assert fields_map[:enabled] == [default: false, type: :boolean]
      assert fields_map[:name] == [default: "test", type: :string]
      assert fields_map[:data] == [default: %{key: "value"}, type: :map]
      assert fields_map[:items] == [default: [1, 2, 3], type: :list]
      assert fields_map[:rate] == [default: 3.14, type: :float]
      assert fields_map[:atom_val] == [default: :test, type: :atom]
      assert fields_map[:nil_val] == [default: nil, type: :any]
    end

    test "type inference works correctly for individual types" do
      alias EngineSystem.Engine.DSL.EnvironmentBuilder

      # Test individual type inference
      assert EnvironmentBuilder.generate_fields_from_map(%{bool_val: true}) ==
               [bool_val: [default: true, type: :boolean]]

      assert EnvironmentBuilder.generate_fields_from_map(%{bool_val: false}) ==
               [bool_val: [default: false, type: :boolean]]

      assert EnvironmentBuilder.generate_fields_from_map(%{int_val: 42}) ==
               [int_val: [default: 42, type: :integer]]

      assert EnvironmentBuilder.generate_fields_from_map(%{float_val: 3.14}) ==
               [float_val: [default: 3.14, type: :float]]

      assert EnvironmentBuilder.generate_fields_from_map(%{string_val: "hello"}) ==
               [string_val: [default: "hello", type: :string]]

      assert EnvironmentBuilder.generate_fields_from_map(%{atom_val: :test}) ==
               [atom_val: [default: :test, type: :atom]]

      assert EnvironmentBuilder.generate_fields_from_map(%{list_val: [1, 2, 3]}) ==
               [list_val: [default: [1, 2, 3], type: :list]]

      assert EnvironmentBuilder.generate_fields_from_map(%{map_val: %{key: "value"}}) ==
               [map_val: [default: %{key: "value"}, type: :map]]

      assert EnvironmentBuilder.generate_fields_from_map(%{nil_val: nil}) ==
               [nil_val: [default: nil, type: :any]]
    end

    test "simple counter engine uses simplified environment syntax correctly" do
      # Test that our example engine compiles and has the correct spec
      spec = Examples.SimpleCounterEngine.__engine_spec__()

      # Verify basic engine properties
      assert spec.name == Examples.SimpleCounterEngine
      assert spec.version == "2.0.0"

      # Check environment spec uses simplified syntax
      env_spec = spec.env_spec
      # Generic name from simplified syntax
      assert env_spec.name == :environment

      # Verify the default environment values
      expected_defaults = %{
        counter: 0,
        increment_by: 1,
        max_count: 100,
        enabled: true,
        history: [],
        metadata: %{}
      }

      assert env_spec.default == expected_defaults

      # Verify auto-generated field definitions with correct type inference
      assert length(env_spec.fields) == 6

      fields_map = Map.new(env_spec.fields)
      assert fields_map[:counter][:type] == :integer
      assert fields_map[:counter][:default] == 0

      assert fields_map[:increment_by][:type] == :integer
      assert fields_map[:increment_by][:default] == 1

      assert fields_map[:max_count][:type] == :integer
      assert fields_map[:max_count][:default] == 100

      assert fields_map[:enabled][:type] == :boolean
      assert fields_map[:enabled][:default] == true

      assert fields_map[:history][:type] == :list
      assert fields_map[:history][:default] == []

      assert fields_map[:metadata][:type] == :map
      assert fields_map[:metadata][:default] == %{}

      # Check that config also uses simplified syntax
      config_spec = spec.config_spec
      assert config_spec.name == :config
      assert config_spec.default == %{mode: :unlimited, auto_reset: false, notifications: true}

      config_fields = Map.new(config_spec.fields)
      assert config_fields[:mode][:type] == :atom
      assert config_fields[:auto_reset][:type] == :boolean
      assert config_fields[:notifications][:type] == :boolean
    end

    test "backward compatibility with existing engines" do
      # Test that existing engines still work
      spec = Examples.KVStoreEngine.__engine_spec__()

      # Verify basic properties
      assert spec.name == Examples.KVStoreEngine
      assert spec.version == "1.0.0"

      # Check that old verbose syntax still works
      env_spec = spec.env_spec
      # Named environment from old syntax
      assert env_spec.name == :environment
      assert env_spec.default == %{store: %{}, access_counts: %{}}

      # Verify field definitions exist
      assert length(env_spec.fields) == 2
      fields_map = Map.new(env_spec.fields)
      assert fields_map[:store][:type] == :map
      assert fields_map[:access_counts][:type] == :map
    end

    test "stateless engines get default environment" do
      # Test that stateless calculator engine gets default environment
      spec = Examples.StatelessCalculatorEngine.__engine_spec__()

      env_spec = spec.env_spec
      # Should get default stateless environment since no environment block is defined
      assert env_spec.name == :stateless_env
      assert env_spec.default == %{}
      assert env_spec.fields == []
    end
  end
end
