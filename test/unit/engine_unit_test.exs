defmodule EngineSystem.Unit.EngineTest do
  use ExUnit.Case, async: true
  doctest EngineSystem.Engine.DSL

  alias EngineSystem.Engine.EngineProcess.{Utils, Types, StateManager, Evaluator, EffectProcessor}

  describe "Engine Utils" do
    test "generates unique addresses and message IDs" do
      # Test address generation
      address1 = Utils.generate_engine_address()
      address2 = Utils.generate_engine_address()

      assert {:engine, _, _} = address1
      assert {:engine, _, _} = address2
      assert address1 != address2

      # Test message ID generation
      msg_id1 = Utils.generate_message_id()
      msg_id2 = Utils.generate_message_id()

      assert is_binary(msg_id1)
      assert is_binary(msg_id2)
      assert msg_id1 != msg_id2
    end
  end

  describe "StateManager" do
    test "creates engine info correctly" do
      state = %{
        address: {:engine, node(), 123},
        engine_name: "TestEngine",
        engine_spec: %{type_version: "1.0"},
        status: {:ready, &EngineSystem.Types.EngineStatus.default_filter/0},
        creation_timestamp: 1_234_567_890,
        last_status_change_timestamp: 1_234_567_890,
        operational_mode: :process,
        mailbox: []
      }

      info = StateManager.create_engine_info(state)

      assert info.address == state.address
      assert info.type_name == "TestEngine"
      assert info.type_version == "1.0"
      assert info.mailbox_size == 0
    end
  end

  describe "Evaluator" do
    test "builds bindings from payload correctly" do
      # Test with list binding and tuple payload
      bindings_ast = [:key, :value]
      # Just the payload part, not including the message tag
      payload = {"test_key", "test_value"}

      bindings = Evaluator.build_bindings_from_payload(bindings_ast, payload)

      assert bindings.key == "test_key"
      assert bindings.value == "test_value"
    end

    test "handles different payload types" do
      # Test with atom payload
      bindings_ast = [:message]
      payload = :hello

      bindings = Evaluator.build_bindings_from_payload(bindings_ast, payload)
      assert bindings.message == :hello

      # Test with complex nested payload
      bindings_ast = [:user, :action, :data]
      payload = {"john", :update, %{age: 30}}

      bindings = Evaluator.build_bindings_from_payload(bindings_ast, payload)
      assert bindings.user == "john"
      assert bindings.action == :update
      assert bindings.data == %{age: 30}
    end
  end

  describe "EffectProcessor" do
    test "processes update effects correctly" do
      environment = %{store: %{}}

      # Test update effect
      result = [{:update, %{store: %{"key" => "value"}}}]
      {new_env, effects} = EffectProcessor.process_action_result(result, environment)

      assert new_env == %{store: %{"key" => "value"}}
      assert effects == :noop
    end

    test "processes send effects correctly" do
      environment = %{store: %{}}

      # Test send effect
      result = [{:send, {:engine, node(), 123}, {:result, "value"}}]
      {new_env, effect} = EffectProcessor.process_action_result(result, environment)

      assert new_env == environment
      assert effect == {:send, {:engine, node(), 123}, {:result, "value"}}
    end

    test "processes single effects correctly" do
      environment = %{store: %{}}

      # Test single update effect
      result = {:update, %{store: %{"single" => "value"}}}
      {new_env, effect} = EffectProcessor.process_action_result(result, environment)

      assert new_env == %{store: %{"single" => "value"}}
      assert effect == :noop

      # Test noop effect
      {new_env, effect} = EffectProcessor.process_action_result(:noop, environment)

      assert new_env == environment
      assert effect == :noop
    end

    test "processes chain effects correctly" do
      environment = %{store: %{}}

      # Test chain effect for multiple actions
      result = [
        {:send, {:engine, node(), 123}, {:ack}},
        {:update, %{store: %{"chained" => "value"}}}
      ]

      {new_env, effect} = EffectProcessor.process_action_result(result, environment)

      assert new_env == %{store: %{"chained" => "value"}}
      assert {:chain, {:send, {:engine, _, 123}, {:ack}}, :noop} = effect
    end

    test "handles complex effect chains" do
      environment = %{counter: 0, messages: []}

      # Test multiple updates and sends
      result = [
        {:update, %{counter: 1}},
        {:send, {:engine, node(), 123}, {:notification, "first"}},
        {:update, %{counter: 2, messages: ["hello"]}},
        {:send, {:engine, node(), 456}, {:notification, "second"}}
      ]

      {new_env, effect} = EffectProcessor.process_action_result(result, environment)

      assert new_env == %{counter: 2, messages: ["hello"]}
      # Should chain all the send effects
      assert {:chain, _, _} = effect
    end
  end

  describe "Types module" do
    test "defines consistent types" do
      # This is a compile-time test to ensure types are properly defined
      assert Types.module_info(:exports) |> length() > 0
    end
  end
end
