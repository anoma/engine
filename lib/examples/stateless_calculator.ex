import EngineSystem.Engine.DSL

defengine Examples.StatelessCalculatorEngine do
  @moduledoc "Simple stateless calculator for basic arithmetic."

  version("2.0.0")

  interface do
    message(:add, a: :number, b: :number)
    message(:subtract, a: :number, b: :number)
    message(:multiply, a: :number, b: :number)
    message(:divide, a: :number, b: :number)
    message(:factorial, n: :integer)
    message(:sqrt, n: :number)
    message(:result, value: :number)
    message(:error, reason: :atom)
  end

  config do
    %{
      max_number: 1_000_000,
      decimal_precision: 10,
      allow_negative: true
    }
  end

  # Stateless - no environment state

  message_filter(fn _msg, _config, _env -> true end)

  behaviour do
    on_message :add, %{a: a, b: b}, _config, _env, sender do
      result = a + b
      {:ok, [{:send, sender, {:result, result}}]}
    end

    on_message :subtract, %{a: a, b: b}, _config, _env, sender do
      result = a - b
      {:ok, [{:send, sender, {:result, result}}]}
    end

    on_message :multiply, %{a: a, b: b}, _config, _env, sender do
      result = a * b
      {:ok, [{:send, sender, {:result, result}}]}
    end

    on_message :divide, %{a: a, b: b}, _config, _env, sender do
      if b == 0 do
        {:ok, [{:send, sender, {:error, :division_by_zero}}]}
      else
        result = a / b
        {:ok, [{:send, sender, {:result, result}}]}
      end
    end

    on_message :factorial, %{n: n}, _config, _env, sender do
      if n > 20 do
        {:ok, [{:send, sender, {:error, :overflow}}]}
      else
        result = Enum.reduce(1..n, 1, &*/2)
        {:ok, [{:send, sender, {:result, result}}]}
      end
    end

    on_message :sqrt, %{n: n}, _config, _env, sender do
      if n < 0 do
        {:ok, [{:send, sender, {:error, :negative_number}}]}
      else
        result = :math.sqrt(n)
        {:ok, [{:send, sender, {:result, result}}]}
      end
    end
  end
end
