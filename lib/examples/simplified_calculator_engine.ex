import EngineSystem.Engine.DSL

defengine Examples.SimplifiedCalculatorEngine do
  @moduledoc """
  Simplified Calculator Engine demonstrating the new streamlined configuration syntax.

  This engine shows how the configuration can be simplified by:

  1. **Eliminating redundant default values** - Values are specified only once
  2. **Removing unnecessary config names** - The DSL automatically handles naming
  3. **Automatic type inference** - Types are inferred from the provided values
  4. **Cleaner, more readable syntax** - Less boilerplate, more intention-revealing

  ## Old Syntax (Redundant)

  ```elixir
  config calc_config: %{
    max_number: 1_000_000,
    decimal_precision: 10,
    allow_negative: true
  } do
    field(:max_number, default: 1_000_000, type: :integer)      # Redundant!
    field(:decimal_precision, default: 10, type: :integer)     # Redundant!
    field(:allow_negative, default: true, type: :boolean)      # Redundant!
  end
  ```

  ## New Syntax (Simplified)

  ```elixir
  config do
    %{
      max_number: 1_000_000,
      decimal_precision: 10,
      allow_negative: true
    }
  end
  ```

  The DSL automatically:
  - Infers `:integer` type from `1_000_000` and `10`
  - Infers `:boolean` type from `true`
  - Sets default values from the map values
  - Creates field definitions internally

  ## Benefits

  - **50% fewer lines of code** for configuration
  - **Eliminates duplication** of values and types
  - **Reduces errors** from mismatched defaults/fields
  - **Cleaner, more maintainable** configuration definitions
  """
  version("2.0.0")

  # Simplified configuration syntax - no redundancy!
  config do
    %{
      max_number: 1_000_000,
      decimal_precision: 10,
      allow_negative: true,
      operator_precision: 0.001
    }
  end

  # Message interface - same as before
  interface do
    message(:add, a: :number, b: :number)
    message(:subtract, a: :number, b: :number)
    message(:multiply, a: :number, b: :number)
    message(:divide, a: :number, b: :number)
    message(:power, base: :number, exponent: :integer)
    message(:result, value: :number)
    message(:error, reason: :atom, details: :any)
  end

  # Accept all messages
  message_filter(fn _msg, _config, _env -> true end)

  # Behavior implementation
  behaviour do
    on_message :add do
      quote do
        case msg_payload do
          {a, b} when is_number(a) and is_number(b) ->
            # Configuration access is the same
            max_number = get_in(config_data.local_state, [:max_number])
            result = a + b

            if abs(result) <= max_number do
              if msg_sender_address do
                {:ok, [{:send, msg_sender_address, {:result, result}}]}
              else
                {:ok, [:noop]}
              end
            else
              if msg_sender_address do
                {:ok, [{:send, msg_sender_address, {:error, :overflow, "Result too large"}}]}
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
              precision = get_in(config_data.local_state, [:decimal_precision])
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
  end
end
