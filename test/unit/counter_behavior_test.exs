defmodule EngineSystem.Unit.CounterBehaviorTest do
  use ExUnit.Case, async: false

  alias EngineSystem.Engine.{Behaviour, State}
  alias EngineSystem.System.Message
  alias Examples.CounterEngine

  @moduledoc """
  Unit tests specifically for counter engine behavior evaluation.

  These tests focus on the counter engine's behavior rules and state management
  without requiring full system integration. They test:
  1. Individual message handler behavior
  2. State transitions and environment updates
  3. Configuration parameter effects
  4. Error conditions and edge cases
  """

  setup do
    # Start the EngineSystem to ensure specs are registered
    {:ok, _} = EngineSystem.start()

    # Ensure the SimpleCounterEngine module is loaded and its spec is registered
    Code.ensure_loaded(CounterEngine)

    # Manually register the spec to ensure it's available
    spec = CounterEngine.__engine_spec__()
    EngineSystem.register_spec(spec)

    :ok
  end

  describe "counter behavior rules" do
    setup do
      # Get the counter engine specification using the correct API
      {:ok, spec} = EngineSystem.lookup_spec(CounterEngine, "2.0.0")

      config =
        State.Configuration.new(nil, :process, %{
          mode: :unlimited,
          auto_reset: false,
          notifications: true
        })

      env =
        State.Environment.new(
          %{
            counter: 0,
            increment_by: 1,
            max_count: 100,
            enabled: true,
            history: [],
            metadata: %{}
          },
          %{}
        )

      {:ok, spec: spec, config: config, env: env}
    end

    test "increment behavior increases counter", %{spec: spec, config: config, env: env} do
      message = Message.new({:test, 1}, {1, 1}, {:increment, %{}})

      {:ok, effects} = Behaviour.evaluate(spec, message, config, env)

      # Should have update_environment and send effects
      assert length(effects) >= 2

      # Find the update_environment effect
      update_effect =
        Enum.find(effects, fn
          {:update_environment, _} -> true
          _ -> false
        end)

      assert update_effect != nil
      {:update_environment, new_env_data} = update_effect

      # Counter should be incremented
      assert new_env_data.counter == 1
      # Previous value added to history
      assert new_env_data.history == [0]
    end

    test "decrement behavior decreases counter", %{spec: spec, config: config} do
      # Start with counter at 5
      env =
        State.Environment.new(
          %{
            counter: 5,
            increment_by: 1,
            max_count: 100,
            enabled: true,
            history: [0, 1, 2, 3, 4],
            metadata: %{}
          },
          %{}
        )

      message = Message.new({:test, 1}, {1, 1}, {:decrement, %{}})

      {:ok, effects} = Behaviour.evaluate(spec, message, config, env)

      # Find the update_environment effect
      update_effect =
        Enum.find(effects, fn
          {:update_environment, _} -> true
          _ -> false
        end)

      assert update_effect != nil
      {:update_environment, new_env_data} = update_effect

      # Counter should be decremented
      assert new_env_data.counter == 4
      # Previous value added to history
      assert new_env_data.history == [5, 0, 1, 2, 3, 4]
    end

    test "decrement doesn't go below zero", %{spec: spec, config: config, env: env} do
      message = Message.new({:test, 1}, {1, 1}, {:decrement, %{}})

      {:ok, effects} = Behaviour.evaluate(spec, message, config, env)

      # Find the update_environment effect
      update_effect =
        Enum.find(effects, fn
          {:update_environment, _} -> true
          _ -> false
        end)

      assert update_effect != nil
      {:update_environment, new_env_data} = update_effect

      # Counter should stay at 0
      assert new_env_data.counter == 0
    end

    test "get_count returns current value without changing state", %{
      spec: spec,
      config: config,
      env: env
    } do
      message = Message.new({:test, 1}, {1, 1}, {:get_count, %{}})

      {:ok, effects} = Behaviour.evaluate(spec, message, config, env)

      # Should only have send effect, no update_environment
      send_effects =
        Enum.filter(effects, fn
          {:send, _, _} -> true
          _ -> false
        end)

      update_effects =
        Enum.filter(effects, fn
          {:update_environment, _} -> true
          _ -> false
        end)

      assert length(send_effects) == 1
      assert length(update_effects) == 0

      # Verify the response
      [{:send, sender, response}] = send_effects
      assert sender == {:test, 1}
      assert response == {:count, 0}
    end

    test "reset sets counter to zero and clears history", %{spec: spec, config: config} do
      # Start with non-zero counter and some history
      env =
        State.Environment.new(
          %{
            counter: 42,
            increment_by: 1,
            max_count: 100,
            enabled: true,
            history: [0, 10, 20, 30],
            metadata: %{}
          },
          %{}
        )

      message = Message.new({:test, 1}, {1, 1}, {:reset, %{}})

      {:ok, effects} = Behaviour.evaluate(spec, message, config, env)

      # Find the update_environment effect
      update_effect =
        Enum.find(effects, fn
          {:update_environment, _} -> true
          _ -> false
        end)

      assert update_effect != nil
      {:update_environment, new_env_data} = update_effect

      # Counter should be reset to 0 and history cleared
      assert new_env_data.counter == 0
      assert new_env_data.history == []
    end

    test "add increases counter by specified value", %{spec: spec, config: config, env: env} do
      message = Message.new({:test, 1}, {1, 1}, {:add, %{value: 7}})

      {:ok, effects} = Behaviour.evaluate(spec, message, config, env)

      # Find the update_environment effect
      update_effect =
        Enum.find(effects, fn
          {:update_environment, _} -> true
          _ -> false
        end)

      assert update_effect != nil
      {:update_environment, new_env_data} = update_effect

      # Counter should be increased by 7
      assert new_env_data.counter == 7
    end
  end

  describe "configuration effects" do
    test "limited mode prevents exceeding max_count" do
      {:ok, spec} = EngineSystem.lookup_spec(CounterEngine, "2.0.0")

      config =
        State.Configuration.new(nil, :process, %{
          mode: :limited,
          notifications: true
        })

      env =
        State.Environment.new(
          %{
            counter: 95,
            increment_by: 1,
            max_count: 100,
            enabled: true,
            history: [],
            metadata: %{}
          },
          %{}
        )

      # Try to add a value that would exceed max_count
      message = Message.new({:test, 1}, {1, 1}, {:add, %{value: 10}})

      {:ok, effects} = Behaviour.evaluate(spec, message, config, env)

      # Should get an error response, no environment update
      send_effects =
        Enum.filter(effects, fn
          {:send, _, _} -> true
          _ -> false
        end)

      update_effects =
        Enum.filter(effects, fn
          {:update_environment, _} -> true
          _ -> false
        end)

      assert length(send_effects) == 1
      assert length(update_effects) == 0

      [{:send, _, response}] = send_effects
      assert response == {:error, :max_count_reached}
    end

    test "notifications configuration affects response format" do
      {:ok, spec} = EngineSystem.lookup_spec(CounterEngine, "2.0.0")

      # Test with notifications enabled
      config_with_notifications =
        State.Configuration.new(nil, :process, %{
          mode: :unlimited,
          notifications: true
        })

      env =
        State.Environment.new(
          %{
            counter: 0,
            increment_by: 1,
            max_count: 100,
            enabled: true,
            history: [],
            metadata: %{}
          },
          %{}
        )

      message = Message.new({:test, 1}, {1, 1}, {:increment, %{}})

      {:ok, effects} = Behaviour.evaluate(spec, message, config_with_notifications, env)

      # Find the send effect
      send_effect =
        Enum.find(effects, fn
          {:send, _, _} -> true
          _ -> false
        end)

      assert send_effect != nil
      {:send, _, response} = send_effect

      # Should get count_updated format when notifications are enabled
      assert response == {:count_updated, 1}

      # Test with notifications disabled
      config_without_notifications =
        State.Configuration.new(nil, :process, %{
          mode: :unlimited,
          notifications: false
        })

      env_reset =
        State.Environment.new(
          %{
            counter: 0,
            increment_by: 1,
            max_count: 100,
            enabled: true,
            history: [],
            metadata: %{}
          },
          %{}
        )

      {:ok, effects2} = Behaviour.evaluate(spec, message, config_without_notifications, env_reset)

      send_effect2 =
        Enum.find(effects2, fn
          {:send, _, _} -> true
          _ -> false
        end)

      assert send_effect2 != nil
      {:send, _, response2} = send_effect2

      # Should get simple ok format when notifications are disabled
      assert response2 == {:ok, 1}
    end

    test "increment_by affects increment amount" do
      {:ok, spec} = EngineSystem.lookup_spec(CounterEngine, "2.0.0")

      config =
        State.Configuration.new(nil, :process, %{
          mode: :unlimited,
          notifications: false
        })

      env =
        State.Environment.new(
          %{
            counter: 10,
            # Custom increment
            increment_by: 5,
            max_count: 100,
            enabled: true,
            history: [],
            metadata: %{}
          },
          %{}
        )

      message = Message.new({:test, 1}, {1, 1}, {:increment, %{}})

      {:ok, effects} = Behaviour.evaluate(spec, message, config, env)

      # Find the update_environment effect
      update_effect =
        Enum.find(effects, fn
          {:update_environment, _} -> true
          _ -> false
        end)

      assert update_effect != nil
      {:update_environment, new_env_data} = update_effect

      # Counter should be increased by increment_by value (5)
      assert new_env_data.counter == 15
    end
  end

  describe "environment state handling" do
    test "disabled counter rejects operations" do
      {:ok, spec} = EngineSystem.lookup_spec(CounterEngine, "2.0.0")

      config =
        State.Configuration.new(nil, :process, %{
          mode: :unlimited,
          notifications: true
        })

      env =
        State.Environment.new(
          %{
            counter: 5,
            increment_by: 1,
            max_count: 100,
            # Disabled
            enabled: false,
            history: [],
            metadata: %{}
          },
          %{}
        )

      message = Message.new({:test, 1}, {1, 1}, {:increment, %{}})

      {:ok, effects} = Behaviour.evaluate(spec, message, config, env)

      # Should get error response, no environment update
      send_effects =
        Enum.filter(effects, fn
          {:send, _, _} -> true
          _ -> false
        end)

      update_effects =
        Enum.filter(effects, fn
          {:update_environment, _} -> true
          _ -> false
        end)

      assert length(send_effects) == 1
      assert length(update_effects) == 0

      [{:send, _, response}] = send_effects
      assert response == {:error, :counter_disabled}
    end

    test "history is maintained correctly" do
      {:ok, spec} = EngineSystem.lookup_spec(CounterEngine, "2.0.0")

      config =
        State.Configuration.new(nil, :process, %{
          mode: :unlimited,
          notifications: false
        })

      env =
        State.Environment.new(
          %{
            counter: 3,
            increment_by: 2,
            max_count: 100,
            enabled: true,
            # Existing history
            history: [0, 1],
            metadata: %{}
          },
          %{}
        )

      message = Message.new({:test, 1}, {1, 1}, {:increment, %{}})

      {:ok, effects} = Behaviour.evaluate(spec, message, config, env)

      # Find the update_environment effect
      update_effect =
        Enum.find(effects, fn
          {:update_environment, _} -> true
          _ -> false
        end)

      assert update_effect != nil
      {:update_environment, new_env_data} = update_effect

      # Counter should be updated and previous value added to history
      assert new_env_data.counter == 5
      # Previous counter value prepended
      assert new_env_data.history == [3, 0, 1]
    end
  end

  describe "error handling" do
    test "handles invalid message format gracefully" do
      {:ok, spec} = EngineSystem.lookup_spec(CounterEngine, "2.0.0")

      config = State.Configuration.new(nil, :process, %{})
      env = State.Environment.new(%{}, %{})

      # Invalid message format
      result = Behaviour.evaluate(spec, "invalid_message", config, env)
      assert {:error, {:invalid_message_format, _}} = result
    end

    test "handles messages not in interface" do
      {:ok, spec} = EngineSystem.lookup_spec(CounterEngine, "2.0.0")

      config = State.Configuration.new(nil, :process, %{})
      env = State.Environment.new(%{}, %{})

      # Message not in the counter engine's interface
      message = Message.new({:test, 1}, {1, 1}, {:unknown_message, %{}})

      {:ok, effects} = Behaviour.evaluate(spec, message, config, env)

      # Should return noop effect when no rule matches
      assert is_list(effects)
      assert length(effects) >= 1
    end
  end
end
