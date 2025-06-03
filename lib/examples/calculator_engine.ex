use EngineSystem

defengine Examples.CalculatorEngine do
  @moduledoc """
  ## Who I Am

  I am a precision calculator engine that performs mathematical operations with
  comprehensive error handling and configurable constraints. I demonstrate how
  engines can implement domain-specific logic while maintaining type safety
  and operational reliability.

  ## My Purpose

  I serve multiple roles within the EngineSystem ecosystem:
  - **Mathematical Services**: I provide reliable arithmetic operations for other engines
  - **Type Safety Demonstration**: I enforce strict typing on numerical operations
  - **Error Handling Example**: I showcase comprehensive edge case handling
  - **Configuration Showcase**: I demonstrate the simplified config syntax with automatic type inference
  - **Precision Control**: I maintain mathematical precision through configurable parameters

  I'm particularly valuable for applications requiring reliable mathematical
  computations with predictable error behavior and precision control.

  ## My Configuration

  I use simplified configuration syntax with automatic type inference:

  ### `max_number` (Integer, default: 1,000,000)
  The maximum absolute value I can return in results. I protect against
  arithmetic overflow by rejecting operations that would exceed this limit.

  ### `decimal_precision` (Integer, default: 10)
  The number of decimal places I maintain in floating-point results. I
  automatically round results to this precision for consistency.

  ### `allow_negative` (Boolean, default: true)
  Whether I permit negative results from operations. When disabled, I
  reject operations that would produce negative values.

  ### `operator_precision` (Float, default: 0.001)
  The minimum value I consider non-zero for division operations. Values
  smaller than this are treated as zero to prevent division-by-zero errors.

  ## Public API (Message Interface)

  I accept four arithmetic operations and provide corresponding responses:

  ### `:add` - Addition Operation
  **Request Format**: `{:add, %{a: float, b: float}}`
  **Response Format**: `{:result, float}` or `{:error, :number_too_large}`
  **Purpose**: Add two floating-point numbers with overflow protection

  ### `:subtract` - Subtraction Operation
  **Request Format**: `{:subtract, %{a: float, b: float}}`
  **Response Format**: `{:result, float}` or `{:error, :negative_not_allowed}`
  **Purpose**: Subtract second number from first with negative handling

  ### `:multiply` - Multiplication Operation
  **Request Format**: `{:multiply, %{a: float, b: float}}`
  **Response Format**: `{:result, float}` or `{:error, :number_too_large}`
  **Purpose**: Multiply two numbers with magnitude limit protection

  ### `:divide` - Division Operation
  **Request Format**: `{:divide, %{a: float, b: float}}`
  **Response Format**: `{:result, float}` or `{:error, :division_by_zero}` or `{:error, :number_too_large}`
  **Purpose**: Divide first number by second with zero-division protection

  ## Message Handling

  Here's exactly what happens when I receive each message type:

  ### When I Receive `:add` Messages

  1. **Input Validation**: I extract float values `a` and `b` from the message payload
  2. **Arithmetic Operation**: I compute `result = a + b` using floating-point arithmetic
  3. **Overflow Check**: I verify `abs(result) <= max_number` to prevent overflow
  4. **Precision Rounding**: I round the result to `decimal_precision` decimal places
  5. **Response Generation**: I send `{:result, rounded_value}` or `{:error, :number_too_large}`

  ```elixir
  # Input:  {:add, %{a: 10.5, b: 5.3}}
  # Process: 10.5 + 5.3 = 15.8, rounded to configured precision
  # Output: {:result, 15.8} sent back to sender
  ```

  ### When I Receive `:subtract` Messages

  1. **Input Validation**: I extract float values `a` and `b` from the payload
  2. **Arithmetic Operation**: I compute `result = a - b`
  3. **Negative Check**: I verify result is non-negative if `allow_negative` is false
  4. **Precision Rounding**: I round to configured decimal precision
  5. **Response Generation**: I send result or negative error based on configuration

  ```elixir
  # Input:  {:subtract, %{a: 10.0, b: 3.0}}
  # Process: 10.0 - 3.0 = 7.0, check negative policy
  # Output: {:result, 7.0} sent back to sender
  ```

  ### When I Receive `:multiply` Messages

  1. **Input Validation**: I extract and validate float operands
  2. **Arithmetic Operation**: I compute `result = a * b`
  3. **Magnitude Check**: I verify the result doesn't exceed maximum allowed value
  4. **Precision Control**: I apply decimal precision rounding
  5. **Error Handling**: I generate appropriate error for magnitude overflow

  ```elixir
  # Input:  {:multiply, %{a: 2.5, b: 4.0}}
  # Process: 2.5 * 4.0 = 10.0, check magnitude limits
  # Output: {:result, 10.0} sent back to sender
  ```

  ### When I Receive `:divide` Messages

  1. **Input Validation**: I extract dividend `a` and divisor `b`
  2. **Zero Check**: I verify `abs(b) >= operator_precision` to prevent division by zero
  3. **Arithmetic Operation**: I compute `result = a / b` if divisor is valid
  4. **Magnitude Verification**: I check result magnitude against limits
  5. **Precision & Response**: I round and send result or appropriate error

  ```elixir
  # Input:  {:divide, %{a: 22.0, b: 7.0}}
  # Process: 22.0 / 7.0 = 3.142857..., round to precision
  # Output: {:result, 3.1428571429} sent back to sender
  ```

  ## Error Conditions

  I generate specific errors for different failure scenarios:

  ### `:number_too_large`
  Returned when any operation result exceeds the configured `max_number` limit.
  This protects against arithmetic overflow and maintains system stability.

  ### `:negative_not_allowed`
  Returned when subtraction produces negative results but `allow_negative` is false.
  This enforces domain-specific constraints on mathematical operations.

  ### `:division_by_zero`
  Returned when division attempts involve divisors smaller than `operator_precision`.
  This prevents mathematical undefined behavior and system crashes.

  ## Usage Examples

  ### Basic Arithmetic Operations
  ```elixir
  # Spawn me with default configuration
  {:ok, calc_addr} = EngineSystem.API.spawn_engine(Examples.CalculatorEngine)

  # Perform addition
  EngineSystem.API.send_message(calc_addr, {:add, %{a: 10.5, b: 5.3}})
  # I respond with: {:result, 15.8}

  # Perform division
  EngineSystem.API.send_message(calc_addr, {:divide, %{a: 22.0, b: 7.0}})
  # I respond with: {:result, 3.1428571429}
  ```

  ### Custom Configuration
  ```elixir
  # Spawn me with custom limits
  custom_config = %{
    max_number: 100,
    decimal_precision: 2,
    allow_negative: false
  }
  {:ok, limited_calc} = EngineSystem.API.spawn_engine(Examples.CalculatorEngine, custom_config)

  # Test overflow protection
  EngineSystem.API.send_message(limited_calc, {:multiply, %{a: 50.0, b: 3.0}})
  # I respond with: {:error, :number_too_large}
  ```

  ### Error Handling Examples
  ```elixir
  # Test division by zero
  EngineSystem.API.send_message(calc_addr, {:divide, %{a: 10.0, b: 0.0}})
  # I respond with: {:error, :division_by_zero}

  # Test negative restriction (if configured)
  EngineSystem.API.send_message(limited_calc, {:subtract, %{a: 5.0, b: 10.0}})
  # I respond with: {:error, :negative_not_allowed}
  ```

  ## Integration Scenarios

  I'm particularly useful in these scenarios:
  - **Financial Systems**: Calculations requiring precision and overflow protection
  - **Scientific Computing**: Mathematical operations with controlled precision
  - **API Services**: Providing calculation services to other engines or systems
  - **Configuration Testing**: Demonstrating simplified config syntax usage
  - **Error Pattern Learning**: Teaching comprehensive error handling patterns

  ## Design Philosophy

  I embody several key design principles:
  - **Type Safety**: I enforce strict typing on all mathematical inputs
  - **Precision Control**: I provide configurable precision for consistent results
  - **Error Transparency**: I provide clear, specific error messages for all failure modes
  - **Configuration Flexibility**: I adapt behavior through runtime configuration
  - **Mathematical Reliability**: I protect against common arithmetic pitfalls

  I serve as both a practical utility for mathematical operations and an
  educational example of how to build robust, configurable engines with
  comprehensive error handling within the EngineSystem.
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
