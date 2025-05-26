import EngineSystem.Engine.DSL

defengine Examples.TickerEngine do
  @moduledoc """
  I am the Ticker Engine.
  """
  version("1.0.0")

  interface do
    message(:tick)
    message(:count, value: :integer)
    message(:get_count)
    message(:reset)
    message(:count_response, value: :integer)
    message(:ack)
  end

  config ticker_config: %{
           max_value: 1000,
           min_value: 0,
           auto_reset: false
         } do
    field(:max_value, default: 1000, type: :integer)
    field(:min_value, default: 0, type: :integer)
    field(:auto_reset, default: false, type: :boolean)
  end

  # Environment containing the counter state
  environment ticker_env: %{count_value: 0} do
    field(:count_value, default: 0, type: :integer)
  end

  # Accept all messages (no filtering)
  message_filter(fn _msg, _config, _env -> true end)

  # Behavior implementing ticker functionality
  behaviour do
    # Tick operation - increment counter by 1
    on_message :tick do
      quote do
        # Get current count value
        current_count = get_in(env_data.local_state, [:count_value]) || 0
        max_value = get_in(config_data.local_state, [:max_value]) || 1000
        auto_reset = get_in(config_data.local_state, [:auto_reset]) || false

        # Calculate new count value
        new_count = current_count + 1

        # Check if we've exceeded max_value
        final_count =
          if new_count > max_value do
            if auto_reset do
              0
            else
              max_value
            end
          else
            new_count
          end

        # Update environment with new count
        new_local_state = %{count_value: final_count}
        new_env = %{env_data | local_state: new_local_state}

        # Create effects: update environment and send acknowledgment
        effects = [{:update_environment, new_env}]

        # Add acknowledgment if we have a sender
        final_effects =
          if msg_sender_address do
            effects ++ [{:send, msg_sender_address, :ack}]
          else
            effects
          end

        {:ok, final_effects}
      end
    end

    # Count operation - set counter to specific value
    on_message :count do
      quote do
        # Extract value from message payload
        new_value =
          case msg_payload do
            {value} when is_integer(value) -> value
            value when is_integer(value) -> value
            %{value: value} when is_integer(value) -> value
            _ -> nil
          end

        if new_value != nil do
          # Get configuration constraints
          max_value = get_in(config_data.local_state, [:max_value]) || 1000
          min_value = get_in(config_data.local_state, [:min_value]) || 0

          # Clamp value to valid range
          clamped_value = max(min_value, min(max_value, new_value))

          # Update environment with new count
          new_local_state = %{count_value: clamped_value}
          new_env = %{env_data | local_state: new_local_state}

          # Create effects: update environment and send acknowledgment
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
          # Invalid value, send error if we have a sender
          if msg_sender_address do
            {:ok, [{:send, msg_sender_address, {:error, :invalid_value}}]}
          else
            {:ok, [:noop]}
          end
        end
      end
    end

    # Get count operation - return current counter value
    on_message :get_count do
      quote do
        # Get current count value
        current_count = get_in(env_data.local_state, [:count_value]) || 0

        # Send response if we have a sender
        if msg_sender_address do
          {:ok, [{:send, msg_sender_address, {:count_response, current_count}}]}
        else
          {:ok, [:noop]}
        end
      end
    end

    # Reset operation - set counter to 0
    on_message :reset do
      quote do
        # Update environment with reset count
        new_local_state = %{count_value: 0}
        new_env = %{env_data | local_state: new_local_state}

        # Create effects: update environment and send acknowledgment
        effects = [{:update_environment, new_env}]

        # Add acknowledgment if we have a sender
        final_effects =
          if msg_sender_address do
            effects ++ [{:send, msg_sender_address, :ack}]
          else
            effects
          end

        {:ok, final_effects}
      end
    end
  end
end
