import EngineSystem.Engine.DSL

defengine Examples.SimpleCounterEngine do
  @moduledoc """
  Simple Counter Engine demonstrating the new simplified environment syntax.

  This engine showcases the environment simplification features:

  ## New Simplified Syntax (Recommended)

  ```elixir
  environment do
    %{
      counter: 0,
      increment_by: 1,
      max_count: 100,
      enabled: true
    }
  end
  ```

  ## Old Verbose Syntax (Still Supported)

  ```elixir
  environment counter_env: %{counter: 0, increment_by: 1, max_count: 100, enabled: true} do
    field(:counter, default: 0, type: :integer)
    field(:increment_by, default: 1, type: :integer)
    field(:max_count, default: 100, type: :integer)
    field(:enabled, default: true, type: :boolean)
  end
  ```

  ## Benefits of Simplified Syntax

  - **No Redundancy**: Default values are specified only once
  - **Type Inference**: Types are automatically inferred from values
  - **Cleaner Code**: Less verbose, easier to read
  - **Backward Compatible**: Old syntax still works

  ## Type Inference Rules

  - `0` → `:integer`
  - `true/false` → `:boolean`
  - `"string"` → `:string`
  - `:atom` → `:atom`
  - `[]` → `:list`
  - `%{}` → `:map`
  - `1.0` → `:float`
  """
  version("1.0.0")

  interface do
    message(:increment)
    message(:decrement)
    message(:set_value, value: :integer)
    message(:get_value)
    message(:reset)
    message(:enable)
    message(:disable)
    message(:configure, increment_by: :integer, max_count: :integer)
    message(:value_response, value: :integer)
    message(:status_response, enabled: :boolean, counter: :integer)
    message(:ack)
    message(:error, reason: :atom)
  end

  config do
    %{
      mode: :unlimited,
      auto_reset: false,
      notifications: true
    }
  end

  # New simplified environment syntax - automatically infers types!
  environment do
    %{
      # inferred as :integer
      counter: 0,
      # inferred as :integer
      increment_by: 1,
      # inferred as :integer
      max_count: 100,
      # inferred as :boolean
      enabled: true,
      # inferred as :list
      history: [],
      # inferred as :map
      metadata: %{}
    }
  end

  message_filter(fn _msg, _config, _env -> true end)

  behaviour do
    # Increment counter
    on_message :increment do
      quote do
        # Get current environment state
        current_counter = get_in(env_data.local_state, [:counter]) || 0
        increment_by = get_in(env_data.local_state, [:increment_by]) || 1
        max_count = get_in(env_data.local_state, [:max_count]) || 100
        enabled = get_in(env_data.local_state, [:enabled]) || true
        history = get_in(env_data.local_state, [:history]) || []

        if enabled do
          new_counter = current_counter + increment_by

          # Check if we've reached max count
          final_counter = min(new_counter, max_count)

          # Update history
          # Keep last 10 values
          new_history = [final_counter | Enum.take(history, 9)]

          # Update environment
          new_local_state = %{
            env_data.local_state
            | counter: final_counter,
              history: new_history
          }

          new_env = %{env_data | local_state: new_local_state}

          # Create effects
          effects = [{:update_environment, new_env}]

          # Add acknowledgment if we have a sender
          final_effects =
            if msg_sender_address do
              effects ++ [{:send, msg_sender_address, :ack}]
            else
              effects
            end

          {:ok, final_effects}
        else
          # Counter is disabled
          if msg_sender_address do
            {:ok, [{:send, msg_sender_address, {:error, :disabled}}]}
          else
            {:ok, [:noop]}
          end
        end
      end
    end

    # Decrement counter
    on_message :decrement do
      quote do
        current_counter = get_in(env_data.local_state, [:counter]) || 0
        increment_by = get_in(env_data.local_state, [:increment_by]) || 1
        enabled = get_in(env_data.local_state, [:enabled]) || true
        history = get_in(env_data.local_state, [:history]) || []

        if enabled do
          new_counter = max(0, current_counter - increment_by)
          new_history = [new_counter | Enum.take(history, 9)]

          new_local_state = %{
            env_data.local_state
            | counter: new_counter,
              history: new_history
          }

          new_env = %{env_data | local_state: new_local_state}

          effects = [{:update_environment, new_env}]

          final_effects =
            if msg_sender_address do
              effects ++ [{:send, msg_sender_address, :ack}]
            else
              effects
            end

          {:ok, final_effects}
        else
          if msg_sender_address do
            {:ok, [{:send, msg_sender_address, {:error, :disabled}}]}
          else
            {:ok, [:noop]}
          end
        end
      end
    end

    # Get current value
    on_message :get_value do
      quote do
        current_counter = get_in(env_data.local_state, [:counter]) || 0

        if msg_sender_address do
          {:ok, [{:send, msg_sender_address, {:value_response, current_counter}}]}
        else
          {:ok, [:noop]}
        end
      end
    end

    # Set specific value
    on_message :set_value do
      quote do
        new_value =
          case msg_payload do
            {value} when is_integer(value) -> value
            %{value: value} when is_integer(value) -> value
            _ -> nil
          end

        if new_value != nil do
          max_count = get_in(env_data.local_state, [:max_count]) || 100
          enabled = get_in(env_data.local_state, [:enabled]) || true
          history = get_in(env_data.local_state, [:history]) || []

          if enabled do
            clamped_value = max(0, min(new_value, max_count))
            new_history = [clamped_value | Enum.take(history, 9)]

            new_local_state = %{
              env_data.local_state
              | counter: clamped_value,
                history: new_history
            }

            new_env = %{env_data | local_state: new_local_state}
            effects = [{:update_environment, new_env}]

            final_effects =
              if msg_sender_address do
                effects ++ [{:send, msg_sender_address, :ack}]
              else
                effects
              end

            {:ok, final_effects}
          else
            if msg_sender_address do
              {:ok, [{:send, msg_sender_address, {:error, :disabled}}]}
            else
              {:ok, [:noop]}
            end
          end
        else
          if msg_sender_address do
            {:ok, [{:send, msg_sender_address, {:error, :invalid_value}}]}
          else
            {:ok, [:noop]}
          end
        end
      end
    end

    # Reset counter
    on_message :reset do
      quote do
        enabled = get_in(env_data.local_state, [:enabled]) || true

        if enabled do
          new_local_state = %{env_data.local_state | counter: 0, history: [0]}
          new_env = %{env_data | local_state: new_local_state}
          effects = [{:update_environment, new_env}]

          final_effects =
            if msg_sender_address do
              effects ++ [{:send, msg_sender_address, :ack}]
            else
              effects
            end

          {:ok, final_effects}
        else
          if msg_sender_address do
            {:ok, [{:send, msg_sender_address, {:error, :disabled}}]}
          else
            {:ok, [:noop]}
          end
        end
      end
    end

    # Enable counter
    on_message :enable do
      quote do
        new_local_state = %{env_data.local_state | enabled: true}
        new_env = %{env_data | local_state: new_local_state}
        effects = [{:update_environment, new_env}]

        final_effects =
          if msg_sender_address do
            effects ++ [{:send, msg_sender_address, :ack}]
          else
            effects
          end

        {:ok, final_effects}
      end
    end

    # Disable counter
    on_message :disable do
      quote do
        new_local_state = %{env_data.local_state | enabled: false}
        new_env = %{env_data | local_state: new_local_state}
        effects = [{:update_environment, new_env}]

        final_effects =
          if msg_sender_address do
            effects ++ [{:send, msg_sender_address, :ack}]
          else
            effects
          end

        {:ok, final_effects}
      end
    end

    # Configure counter parameters
    on_message :configure do
      quote do
        {increment_by, max_count} =
          case msg_payload do
            {inc, max} -> {inc, max}
            %{increment_by: inc, max_count: max} -> {inc, max}
            _ -> {nil, nil}
          end

        if increment_by && max_count && increment_by > 0 && max_count > 0 do
          new_local_state = %{
            env_data.local_state
            | increment_by: increment_by,
              max_count: max_count
          }

          new_env = %{env_data | local_state: new_local_state}
          effects = [{:update_environment, new_env}]

          final_effects =
            if msg_sender_address do
              effects ++ [{:send, msg_sender_address, :ack}]
            else
              effects
            end

          {:ok, final_effects}
        else
          if msg_sender_address do
            {:ok, [{:send, msg_sender_address, {:error, :invalid_configuration}}]}
          else
            {:ok, [:noop]}
          end
        end
      end
    end
  end
end
