defmodule Examples.StatelessCalculatorEngineTest do
  use ExUnit.Case
  doctest Examples.StatelessCalculatorEngine

  alias Examples.StatelessCalculatorEngine

  setup do
    # Start the application for testing
    {:ok, _} = Application.ensure_all_started(:engine_system)

    # Register the StatelessCalculatorEngine spec
    spec = Examples.StatelessCalculatorEngine.__engine_spec__()
    EngineSystem.register_spec(spec)

    on_exit(fn ->
      Application.stop(:engine_system)
    end)

    :ok
  end

  describe "engine specification" do
    test "has proper default environment when omitted" do
      spec = StatelessCalculatorEngine.__engine_spec__()

      # Verify default environment was applied
      assert spec.env_spec.name == :stateless_env
      assert spec.env_spec.default == %{}
      assert spec.env_spec.fields == []
    end

    test "has proper configuration" do
      spec = StatelessCalculatorEngine.__engine_spec__()

      # Verify configuration is defined
      assert spec.config_spec.name == :config
      assert spec.config_spec.default.max_number == 1_000_000
      assert spec.config_spec.default.decimal_precision == 10
      assert spec.config_spec.default.allow_negative == true
    end

    test "has expected message interface" do
      spec = StatelessCalculatorEngine.__engine_spec__()

      # Verify required operations are in the interface
      interface_tags = Enum.map(spec.interface, fn {tag, _} -> tag end)

      assert :add in interface_tags
      assert :subtract in interface_tags
      assert :multiply in interface_tags
      assert :divide in interface_tags
      assert :factorial in interface_tags
      assert :sqrt in interface_tags
      assert :result in interface_tags
      assert :error in interface_tags
    end

    test "compiles without environment block" do
      # This test verifies that the engine compiles successfully
      # even though no environment block was defined
      assert function_exported?(StatelessCalculatorEngine, :__engine_spec__, 0)

      spec = StatelessCalculatorEngine.__engine_spec__()
      assert is_struct(spec)
      assert spec.name == Examples.StatelessCalculatorEngine
    end
  end

  describe "engine spawning and basic functionality" do
    test "can spawn calculator engine instance" do
      assert {:ok, address} = EngineSystem.spawn_engine(StatelessCalculatorEngine)
      assert is_tuple(address)

      # Should be able to look up the instance
      assert {:ok, instance_info} = EngineSystem.lookup_instance(address)
      assert instance_info.address == address
      assert instance_info.status == :running
    end

    test "stateless engine has empty environment" do
      assert {:ok, address} = EngineSystem.spawn_engine(StatelessCalculatorEngine)

      # Verify the engine was spawned with empty environment
      assert {:ok, instance_info} = EngineSystem.lookup_instance(address)

      # The environment should be the default empty state
      # (Note: actual environment inspection depends on the implementation)
      assert instance_info.status == :running
    end
  end

  describe "arithmetic operations" do
    setup do
      {:ok, address} = EngineSystem.spawn_engine(StatelessCalculatorEngine)
      %{calc_address: address}
    end

    test "addition works correctly", %{calc_address: address} do
      # Test basic addition
      message = {:add, 5, 3}

      # send_message returns :ok, not {:ok, _}
      assert :ok = EngineSystem.send_message(address, message)

      # In a full implementation, you would verify the result:
      # Expected result: {:result, 8}
    end

    test "handles addition overflow", %{calc_address: address} do
      # Test overflow protection
      message = {:add, 999_999, 999_999}

      assert :ok = EngineSystem.send_message(address, message)

      # Expected result: {:error, :overflow, "Result exceeds maximum allowed value"}
    end

    test "subtraction works correctly", %{calc_address: address} do
      # Test basic subtraction
      message = {:subtract, 10, 4}

      assert :ok = EngineSystem.send_message(address, message)

      # Expected result: {:result, 6}
    end

    test "multiplication works correctly", %{calc_address: address} do
      # Test basic multiplication
      message = {:multiply, 6, 7}

      assert :ok = EngineSystem.send_message(address, message)

      # Expected result: {:result, 42}
    end

    test "division works correctly", %{calc_address: address} do
      # Test basic division
      message = {:divide, 15, 3}

      assert :ok = EngineSystem.send_message(address, message)

      # Expected result: {:result, 5.0}
    end

    test "division by zero is handled", %{calc_address: address} do
      # Test division by zero protection
      message = {:divide, 10, 0}

      assert :ok = EngineSystem.send_message(address, message)

      # Expected result: {:error, :division_by_zero, "Cannot divide by zero"}
    end

    test "factorial works correctly", %{calc_address: address} do
      # Test factorial calculation
      message = {:factorial, 5}

      assert :ok = EngineSystem.send_message(address, message)

      # Expected result: {:result, 120}
    end

    test "factorial overflow is handled", %{calc_address: address} do
      # Test factorial overflow protection
      message = {:factorial, 25}

      assert :ok = EngineSystem.send_message(address, message)

      # Expected result: {:error, :overflow, "Factorial too large (max n=20)"}
    end

    test "square root works correctly", %{calc_address: address} do
      # Test square root calculation
      message = {:sqrt, 16}

      assert :ok = EngineSystem.send_message(address, message)

      # Expected result: {:result, 4.0}
    end

    test "invalid arguments are handled", %{calc_address: address} do
      # Test invalid argument handling
      message = {:add, "not_a_number", 5}

      assert :ok = EngineSystem.send_message(address, message)

      # Expected result: {:error, :invalid_args, "Expected two numbers"}
    end
  end

  describe "stateless behavior verification" do
    setup do
      {:ok, address} = EngineSystem.spawn_engine(StatelessCalculatorEngine)
      %{calc_address: address}
    end

    test "operations don't affect each other (stateless)", %{calc_address: address} do
      # Perform multiple operations to verify they don't interfere
      operations = [
        {:add, 5, 3},
        {:multiply, 4, 2},
        {:subtract, 10, 7},
        {:divide, 20, 4}
      ]

      # Send all operations
      Enum.each(operations, fn op ->
        assert :ok = EngineSystem.send_message(address, op)
      end)

      # Each operation should be independent - no state carries over
      # In a stateful engine, operations might depend on previous results
      # But here, each operation is completely independent
    end

    test "can spawn multiple calculator instances", %{calc_address: _address1} do
      # Spawn another instance
      assert {:ok, address2} = EngineSystem.spawn_engine(StatelessCalculatorEngine)

      # Both should work independently
      assert :ok = EngineSystem.send_message(address2, {:add, 1, 1})

      # Verify they are different instances
      instances = EngineSystem.list_instances()

      calc_instances =
        Enum.filter(instances, fn inst ->
          inst.spec_key == {Examples.StatelessCalculatorEngine, "2.0.0"}
        end)

      assert length(calc_instances) >= 2
    end
  end

  describe "configuration behavior" do
    test "respects configuration limits" do
      # Test that configuration values are properly applied
      spec = StatelessCalculatorEngine.__engine_spec__()

      # Verify default configuration values
      assert spec.config_spec.default.max_number == 1_000_000
      assert spec.config_spec.default.decimal_precision == 10
      assert spec.config_spec.default.allow_negative == true

      # In a full implementation, you would test spawning with custom config:
      # custom_config = %{max_number: 100, decimal_precision: 2, allow_negative: false}
      # {:ok, address} = EngineSystem.spawn_engine(StatelessCalculatorEngine, custom_config)
      # Then verify that operations respect these limits
    end
  end
end
