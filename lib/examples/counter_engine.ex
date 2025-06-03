use EngineSystem

defengine Examples.CounterEngine do
  @moduledoc """
  I am a simple counter engine that demonstrates simplified environment syntax
  and stateful operations within the EngineSystem architecture.

  ## My Purpose

  I serve as a fundamental example of stateful engine design, implementing a
  configurable counter that maintains persistent state across message interactions.
  I demonstrate how engines can manage complex state while providing clean,
  intuitive interfaces for common operations.

  ## Core Functionality

  I provide comprehensive counter operations with advanced features:

  ### Basic Operations
  - **Increment**: Increase my counter by a configurable step value
  - **Decrement**: Decrease my counter with automatic floor protection
  - **Reset**: Return my counter to zero and clear history
  - **Get Count**: Retrieve my current counter value
  - **Add Value**: Add arbitrary integer values to my counter

  ### Advanced Features
  - **History Tracking**: I maintain a history of previous counter values
  - **Configurable Limits**: I respect maximum count limits when configured
  - **Enable/Disable State**: I can be temporarily disabled while preserving state
  - **Notification System**: I provide configurable response notifications

  ## Configuration System

  I use a simplified configuration syntax with automatic type inference:

  ### Configuration Options
  - `mode`: `:unlimited` or `:limited` operation mode
  - `auto_reset`: Whether I automatically reset when reaching limits
  - `notifications`: Whether I send detailed response notifications

  ### Environment State
  I maintain rich internal state:
  - `counter`: My current counter value
  - `increment_by`: Step size for increment operations
  - `max_count`: Maximum allowed counter value
  - `enabled`: Whether I'm currently accepting operations
  - `history`: List of previous counter values
  - `metadata`: Additional state information

  ## Message Interface

  I handle five primary message types:

  ### `:increment` Messages
  Increase my counter by the configured step value. I respect limits and
  provide appropriate error responses when limits are exceeded.

  ### `:decrement` Messages
  Decrease my counter by the configured step value with automatic floor
  protection (never going below zero).

  ### `:reset` Messages
  Reset my counter to zero and clear my history, providing a clean slate
  for new operations.

  ### `:get_count` Messages
  Return my current counter value without modifying state, useful for
  monitoring and status checking.

  ### `:add` Messages
  Add arbitrary integer values to my counter, providing flexibility
  beyond the standard increment operation.

  ## Error Handling

  I provide comprehensive error handling for various edge cases:
  - `:max_count_reached` when operations would exceed configured limits
  - `:counter_disabled` when I'm temporarily disabled
  - Graceful handling of invalid operations

  ## Usage Examples

      # Spawn me with default configuration
      {:ok, counter_addr} = EngineSystem.spawn_engine(Examples.CounterEngine)

      # Basic operations
      send_message(counter_addr, {:increment, %{}})
      send_message(counter_addr, {:get_count, %{}})
      send_message(counter_addr, {:add, %{value: 5}})
      send_message(counter_addr, {:reset, %{}})

      # Custom configuration
      custom_config = %{mode: :limited, notifications: false}
      {:ok, limited_counter} = EngineSystem.spawn_engine(Examples.CounterEngine, custom_config)

  ## Design Patterns

  I demonstrate several important engine patterns:
  - **Stateful Operations**: Maintaining persistent data across messages
  - **Configuration Management**: Using simplified config syntax with type inference
  - **Error Handling**: Providing meaningful error responses for edge cases
  - **History Tracking**: Maintaining audit trails of state changes
  - **Conditional Logic**: Respecting configuration settings and operational state
  - **Response Consistency**: Uniform response patterns across all operations

  ## State Management Philosophy

  I embody best practices for engine state management:
  - **Immutable Updates**: All state changes create new state objects
  - **Atomic Operations**: Each message handler completes fully or not at all
  - **State Validation**: I validate state consistency before and after operations
  - **History Preservation**: I maintain operational history for debugging and auditing

  ## Educational Value

  I serve multiple educational purposes:
  - **State Management**: Demonstrating how to handle complex engine state
  - **Configuration Patterns**: Showing simplified config syntax usage
  - **Error Handling**: Implementing comprehensive error response patterns
  - **Message Design**: Providing examples of clean message interface design

  I serve as both a practical utility for applications requiring counter
  functionality and an educational foundation for understanding stateful
  engine design patterns within the EngineSystem.
  """

  version("2.0.0")
  # This is a processing engine
  mode(:process)

  interface do
    message(:increment)
    message(:decrement)
    message(:reset)
    message(:get_count)
    message(:add, value: :integer)
  end

  config do
    %{
      mode: :unlimited,
      auto_reset: false,
      notifications: true
    }
  end

  env do
    %{
      counter: 0,
      increment_by: 1,
      max_count: 100,
      enabled: true,
      history: [],
      metadata: %{}
    }
  end

  behaviour do
    on_message :increment, _payload, config, env, sender do
      if env.enabled do
        new_counter = env.counter + env.increment_by

        if config.mode == :limited and new_counter > env.max_count do
          {:ok, [{:send, sender, {:error, :max_count_reached}}]}
        else
          new_env = %{env | counter: new_counter, history: [env.counter | env.history]}

          response =
            if config.notifications,
              do: {:count_updated, new_counter},
              else: {:ok, new_counter}

          {:ok, [{:update_environment, new_env}, {:send, sender, response}]}
        end
      else
        {:ok, [{:send, sender, {:error, :counter_disabled}}]}
      end
    end

    on_message :decrement, _payload, _config, env, sender do
      if env.enabled do
        new_counter = max(0, env.counter - env.increment_by)
        new_env = %{env | counter: new_counter, history: [env.counter | env.history]}
        {:ok, [{:update_environment, new_env}, {:send, sender, {:ok, new_counter}}]}
      else
        {:ok, [{:send, sender, {:error, :counter_disabled}}]}
      end
    end

    on_message :reset, _payload, _config, env, sender do
      new_env = %{env | counter: 0, history: []}
      {:ok, [{:update_environment, new_env}, {:send, sender, {:ok, :reset}}]}
    end

    on_message :get_count, _payload, _config, env, sender do
      {:ok, [{:send, sender, {:count, env.counter}}]}
    end

    on_message :add, %{value: value}, config, env, sender do
      if env.enabled do
        new_counter = env.counter + value

        if config.mode == :limited and new_counter > env.max_count do
          {:ok, [{:send, sender, {:error, :max_count_reached}}]}
        else
          new_env = %{env | counter: new_counter}
          {:ok, [{:update_environment, new_env}, {:send, sender, {:ok, new_counter}}]}
        end
      else
        {:ok, [{:send, sender, {:error, :counter_disabled}}]}
      end
    end
  end
end
