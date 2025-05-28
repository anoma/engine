import EngineSystem.Engine.DSL

defengine Examples.StatelessCalculatorEngine do
  @moduledoc """
  Stateless Calculator Engine demonstrating default environment behavior.

  This engine demonstrates what happens when you omit the environment block
  in an engine definition. When no environment block is provided, the DSL
  automatically creates a stateless engine with an empty environment:

  - `name: :stateless_env` - Default environment name
  - `default: %{}` - Empty state (no local variables)
  - `fields: []` - No environment fields defined

  This is a pure functional calculator that performs mathematical operations
  without maintaining any state between operations, making it ideal for
  demonstrating stateless engine behavior.

  ## Message Interface

  - `:add` - Add two numbers
  - `:subtract` - Subtract two numbers
  - `:multiply` - Multiply two numbers
  - `:divide` - Divide two numbers (with zero-division protection)
  - `:power` - Raise number to a power
  - `:factorial` - Calculate factorial of a number

  ## Default Environment Applied

  Since no `environment` block is defined, the engine will automatically use:

  ```elixir
  environment stateless_env: %{} do
    # No fields - completely stateless
  end
  ```

  ## Example Usage

  ```elixir
  # Spawn the stateless engine
  {:ok, address} = EngineSystem.spawn_engine(Examples.StatelessCalculatorEngine)

  # Perform calculations (no state maintained between operations)
  EngineSystem.send_message(address, {:add, 5, 3})
  EngineSystem.send_message(address, {:multiply, 4, 7})
  EngineSystem.send_message(address, {:factorial, 5})
  ```

  ## Benefits of Stateless Design

  - **Predictable**: Same input always produces same output
  - **Concurrent**: Multiple operations can run simultaneously safely
  - **Simple**: No state management complexity
  - **Testable**: Easy to test individual operations
  """
  version("1.0.0")

  # Configuration for operation limits and precision
  config calc_config: %{
           max_number: 1_000_000,
           decimal_precision: 10,
           allow_negative: true
         } do
    field(:max_number, default: 1_000_000, type: :integer)
    field(:decimal_precision, default: 10, type: :integer)
    field(:allow_negative, default: true, type: :boolean)
  end

  # Message interface - mathematical operations
  interface do
    # Basic arithmetic operations
    message(:add, a: :number, b: :number)
    message(:subtract, a: :number, b: :number)
    message(:multiply, a: :number, b: :number)
    message(:divide, a: :number, b: :number)

    # Advanced operations
    message(:power, base: :number, exponent: :integer)
    message(:factorial, n: :integer)

    # Utility operations
    message(:abs, n: :number)
    message(:sqrt, n: :number)

    # Response messages
    message(:result, value: :number)
    message(:error, reason: :atom, details: :any)
  end

  # NOTE: No environment block defined here!
  # This demonstrates the default stateless environment behavior.
  # The DSL will automatically apply:
  # environment stateless_env: %{} do
  #   # No fields - completely stateless
  # end

  # Accept all messages (no filtering needed for calculations)
  message_filter(fn _msg, _config, _env -> true end)

  # Behavior implementing stateless mathematical operations
  behaviour do
    # Addition operation
    on_message :add do
      quote do
        case msg_payload do
          {a, b} when is_number(a) and is_number(b) ->
            # Get configuration limits
            max_number = get_in(config_data.local_state, [:max_number]) || 1_000_000

            result = a + b

            if abs(result) <= max_number do
              if msg_sender_address do
                {:ok, [{:send, msg_sender_address, {:result, result}}]}
              else
                {:ok, [:noop]}
              end
            else
              if msg_sender_address do
                {:ok, [{:send, msg_sender_address, {:error, :overflow, "Result exceeds maximum allowed value"}}]}
              else
                {:ok, [:noop]}
              end
            end

          _ ->
            if msg_sender_address do
              {:ok, [{:send, msg_sender_address, {:error, :invalid_args, "Expected two numbers"}}]}
            else
              {:ok, [:noop]}
            end
        end
      end
    end

    # Subtraction operation
    on_message :subtract do
      quote do
        case msg_payload do
          {a, b} when is_number(a) and is_number(b) ->
            max_number = get_in(config_data.local_state, [:max_number]) || 1_000_000
            allow_negative = get_in(config_data.local_state, [:allow_negative]) || true

            result = a - b

            cond do
              abs(result) > max_number ->
                if msg_sender_address do
                  {:ok, [{:send, msg_sender_address, {:error, :overflow, "Result exceeds maximum allowed value"}}]}
                else
                  {:ok, [:noop]}
                end

              not allow_negative and result < 0 ->
                if msg_sender_address do
                  {:ok, [{:send, msg_sender_address, {:error, :negative_result, "Negative results not allowed"}}]}
                else
                  {:ok, [:noop]}
                end

              true ->
                if msg_sender_address do
                  {:ok, [{:send, msg_sender_address, {:result, result}}]}
                else
                  {:ok, [:noop]}
                end
            end

          _ ->
            if msg_sender_address do
              {:ok, [{:send, msg_sender_address, {:error, :invalid_args, "Expected two numbers"}}]}
            else
              {:ok, [:noop]}
            end
        end
      end
    end

    # Multiplication operation
    on_message :multiply do
      quote do
        case msg_payload do
          {a, b} when is_number(a) and is_number(b) ->
            max_number = get_in(config_data.local_state, [:max_number]) || 1_000_000

            result = a * b

            if abs(result) <= max_number do
              if msg_sender_address do
                {:ok, [{:send, msg_sender_address, {:result, result}}]}
              else
                {:ok, [:noop]}
              end
            else
              if msg_sender_address do
                {:ok, [{:send, msg_sender_address, {:error, :overflow, "Result exceeds maximum allowed value"}}]}
              else
                {:ok, [:noop]}
              end
            end

          _ ->
            if msg_sender_address do
              {:ok, [{:send, msg_sender_address, {:error, :invalid_args, "Expected two numbers"}}]}
            else
              {:ok, [:noop]}
            end
        end
      end
    end

    # Division operation with zero-division protection
    on_message :divide do
      quote do
        case msg_payload do
          {a, b} when is_number(a) and is_number(b) ->
            if b == 0 do
              if msg_sender_address do
                {:ok, [{:send, msg_sender_address, {:error, :division_by_zero, "Cannot divide by zero"}}]}
              else
                {:ok, [:noop]}
              end
            else
              precision = get_in(config_data.local_state, [:decimal_precision]) || 10
              result = Float.round(a / b, precision)

              if msg_sender_address do
                {:ok, [{:send, msg_sender_address, {:result, result}}]}
              else
                {:ok, [:noop]}
              end
            end

          _ ->
            if msg_sender_address do
              {:ok, [{:send, msg_sender_address, {:error, :invalid_args, "Expected two numbers"}}]}
            else
              {:ok, [:noop]}
            end
        end
      end
    end

    # Factorial operation
    on_message :factorial do
      quote do
        case msg_payload do
          {n} when is_integer(n) and n >= 0 ->
            if n > 20 do
              if msg_sender_address do
                {:ok, [{:send, msg_sender_address, {:error, :overflow, "Factorial too large (max n=20)"}}]}
              else
                {:ok, [:noop]}
              end
            else
              # Calculate factorial iteratively to avoid stack overflow
              result = Enum.reduce(1..n, 1, &*/2)

              if msg_sender_address do
                {:ok, [{:send, msg_sender_address, {:result, result}}]}
              else
                {:ok, [:noop]}
              end
            end

          {n} when is_integer(n) ->
            if msg_sender_address do
              {:ok, [{:send, msg_sender_address, {:error, :invalid_args, "Factorial requires non-negative integer"}}]}
            else
              {:ok, [:noop]}
            end

          _ ->
            if msg_sender_address do
              {:ok, [{:send, msg_sender_address, {:error, :invalid_args, "Expected non-negative integer"}}]}
            else
              {:ok, [:noop]}
            end
        end
      end
    end

    # Square root operation
    on_message :sqrt do
      quote do
        case msg_payload do
          {n} when is_number(n) and n >= 0 ->
            precision = get_in(config_data.local_state, [:decimal_precision]) || 10
            result = Float.round(:math.sqrt(n), precision)

            if msg_sender_address do
              {:ok, [{:send, msg_sender_address, {:result, result}}]}
            else
              {:ok, [:noop]}
            end

          {n} when is_number(n) ->
            if msg_sender_address do
              {:ok, [{:send, msg_sender_address, {:error, :invalid_args, "Square root requires non-negative number"}}]}
            else
              {:ok, [:noop]}
            end

          _ ->
            if msg_sender_address do
              {:ok, [{:send, msg_sender_address, {:error, :invalid_args, "Expected non-negative number"}}]}
            else
              {:ok, [:noop]}
            end
        end
      end
    end
  end
end
