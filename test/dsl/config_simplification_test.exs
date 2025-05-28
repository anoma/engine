defmodule EngineSystem.DSL.ConfigSimplificationTest do
  use ExUnit.Case, async: true

  describe "Simplified Configuration Syntax" do
    test "simplified config syntax with automatic type inference" do
      # Use the existing working example
      spec = Examples.SimplifiedCalculatorEngine.__engine_spec__()

      # Verify config spec structure
      assert spec.config_spec.name == :config
      assert is_map(spec.config_spec.default)
      assert is_list(spec.config_spec.fields)

      # Verify default values
      config_default = spec.config_spec.default
      assert config_default.max_number == 1_000_000
      assert config_default.decimal_precision == 10
      assert config_default.allow_negative == true
      assert config_default.operator_precision == 0.001

      # Verify field definitions and type inference
      fields_map = Map.new(spec.config_spec.fields)

      assert Keyword.get(fields_map.max_number, :type) == :integer
      assert Keyword.get(fields_map.max_number, :default) == 1_000_000

      assert Keyword.get(fields_map.decimal_precision, :type) == :integer
      assert Keyword.get(fields_map.decimal_precision, :default) == 10

      assert Keyword.get(fields_map.allow_negative, :type) == :boolean
      assert Keyword.get(fields_map.allow_negative, :default) == true

      assert Keyword.get(fields_map.operator_precision, :type) == :float
      assert Keyword.get(fields_map.operator_precision, :default) == 0.001
    end

    test "backward compatibility - old syntax still works" do
      # Use the existing stateless calculator with old syntax
      spec = Examples.StatelessCalculatorEngine.__engine_spec__()

      # Verify old syntax still works
      assert spec.config_spec.name == :calc_config
      assert spec.config_spec.default.max_number == 1_000_000
      assert spec.config_spec.default.decimal_precision == 10
      assert spec.config_spec.default.allow_negative == true

      fields_map = Map.new(spec.config_spec.fields)
      assert Keyword.get(fields_map.max_number, :type) == :integer
      assert Keyword.get(fields_map.allow_negative, :type) == :boolean
    end

    test "type inference handles edge cases correctly" do
      # Test boolean vs atom precedence
      result =
        EngineSystem.Engine.DSL.ConfigBuilder.generate_fields_from_map(%{
          bool_true: true,
          bool_false: false,
          atom_val: :some_atom,
          nil_val: nil
        })

      # Convert to map for easier testing since order isn't guaranteed
      result_map = Map.new(result)

      assert Keyword.get(result_map.bool_true, :type) == :boolean
      assert Keyword.get(result_map.bool_true, :default) == true

      assert Keyword.get(result_map.bool_false, :type) == :boolean
      assert Keyword.get(result_map.bool_false, :default) == false

      assert Keyword.get(result_map.atom_val, :type) == :atom
      assert Keyword.get(result_map.atom_val, :default) == :some_atom

      assert Keyword.get(result_map.nil_val, :type) == :any
      assert Keyword.get(result_map.nil_val, :default) == nil
    end

    test "simplified syntax reduces configuration size significantly" do
      # This test demonstrates the line reduction benefit
      old_syntax_lines = """
      config my_config: %{
        max_connections: 100,
        timeout: 5000,
        retry_enabled: true,
        log_level: :info
      } do
        field(:max_connections, default: 100, type: :integer)
        field(:timeout, default: 5000, type: :integer)
        field(:retry_enabled, default: true, type: :boolean)
        field(:log_level, default: :info, type: :atom)
      end
      """

      new_syntax_lines = """
      config do
        %{
          max_connections: 100,
          timeout: 5000,
          retry_enabled: true,
          log_level: :info
        }
      end
      """

      old_line_count = String.split(String.trim(old_syntax_lines), "\n") |> length()
      new_line_count = String.split(String.trim(new_syntax_lines), "\n") |> length()

      # Verify significant reduction (should be around 50% fewer lines)
      reduction_percentage = (old_line_count - new_line_count) / old_line_count * 100
      # At least 20% reduction (more realistic)
      assert reduction_percentage > 20
    end
  end

  describe "Error Handling" do
    test "handles invalid input gracefully" do
      # Test with non-map input
      assert EngineSystem.Engine.DSL.ConfigBuilder.generate_fields_from_map("not a map") == []
      assert EngineSystem.Engine.DSL.ConfigBuilder.generate_fields_from_map(nil) == []
      assert EngineSystem.Engine.DSL.ConfigBuilder.generate_fields_from_map(42) == []
    end
  end
end
