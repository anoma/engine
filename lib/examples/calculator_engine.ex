use EngineSystem

defengine Examples.CalculatorEngine do
  @moduledoc """
  A simplified calculator engine demonstrating the new simplified config syntax.
  This engine performs basic arithmetic operations with automatic type inference.
  """

  version("1.0.0")
  # This is a processing engine
  mode(:process)

  interface do
    message(:add, a: :float, b: :float)
    message(:subtract, a: :float, b: :float)
    message(:multiply, a: :float, b: :float)
    message(:divide, a: :float, b: :float)
    message(:result, value: :float)
    message(:error, reason: :atom)
  end

  # Simplified config syntax - automatic type inference from the map
  config do
    %{
      max_number: 1_000_000,
      decimal_precision: 10,
      allow_negative: true,
      operator_precision: 0.001
    }
  end

  behaviour do
    on_message :add, %{a: a, b: b}, config, _env, sender do
      result = a + b

      if abs(result) > config.max_number do
        {:ok, [{:send, sender, {:error, :number_too_large}}]}
      else
        rounded = Float.round(result, config.decimal_precision)
        {:ok, [{:send, sender, {:result, rounded}}]}
      end
    end

    on_message :subtract, %{a: a, b: b}, config, _env, sender do
      result = a - b

      if not config.allow_negative and result < 0 do
        {:ok, [{:send, sender, {:error, :negative_not_allowed}}]}
      else
        rounded = Float.round(result, config.decimal_precision)
        {:ok, [{:send, sender, {:result, rounded}}]}
      end
    end

    on_message :multiply, %{a: a, b: b}, config, _env, sender do
      result = a * b

      if abs(result) > config.max_number do
        {:ok, [{:send, sender, {:error, :number_too_large}}]}
      else
        rounded = Float.round(result, config.decimal_precision)
        {:ok, [{:send, sender, {:result, rounded}}]}
      end
    end

    on_message :divide, %{a: a, b: b}, config, _env, sender do
      if abs(b) < config.operator_precision do
        {:ok, [{:send, sender, {:error, :division_by_zero}}]}
      else
        result = a / b

        if abs(result) > config.max_number do
          {:ok, [{:send, sender, {:error, :number_too_large}}]}
        else
          rounded = Float.round(result, config.decimal_precision)
          {:ok, [{:send, sender, {:result, rounded}}]}
        end
      end
    end
  end
end
