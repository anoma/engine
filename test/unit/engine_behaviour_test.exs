defmodule EngineSystem.Unit.EngineBehaviourTest do
  use ExUnit.Case, async: true

  alias EngineSystem.Engine.{Behaviour, Spec, State}
  alias EngineSystem.System.Message

  @moduledoc """
  Unit tests for engine behavior evaluation.

  Tests the core behavior evaluation logic including:
  1. Rule matching and selection
  2. Function handler execution
  3. Configuration and environment handling
  4. Error handling and edge cases
  """

  describe "behavior rule evaluation" do
    test "finds matching rule by message tag" do
      rules = [
        {:ping, {:function_handler, TestModule, :handle_ping}},
        {:pong, {:function_handler, TestModule, :handle_pong}}
      ]

      message = Message.new({:test, 1}, {1, 1}, {:ping, %{data: "test"}})

      result = Behaviour.find_matching_rule(rules, message, nil, nil)
      assert {:ok, {:ping, {:function_handler, TestModule, :handle_ping}}} = result
    end

    test "returns no_match when no rule matches" do
      rules = [
        {:ping, {:function_handler, TestModule, :handle_ping}}
      ]

      message = Message.new({:test, 1}, {1, 1}, {:unknown, %{}})

      result = Behaviour.find_matching_rule(rules, message, nil, nil)
      assert result == :no_match
    end

    test "handles simple tuple messages" do
      rules = [
        {:test_msg, :noop}
      ]

      # Test with simple tuple format
      result = Behaviour.find_matching_rule(rules, {:test_msg, "payload"}, nil, nil)
      assert {:ok, {:test_msg, :noop}} = result
    end

    test "validates rule format" do
      valid_rule = {:ping, :some_action}
      invalid_rule = {"ping", :some_action}

      assert Behaviour.validate_rule(valid_rule) == :ok
      assert {:error, {:invalid_rule_format, _}} = Behaviour.validate_rule(invalid_rule)
    end
  end

  describe "behavior execution" do
    test "executes function handler with correct parameters" do
      # Create test module with handler function
      defmodule TestHandlerModule do
        def test_handler(payload, config, env, sender) do
          {:ok,
           [
             {:test_effect,
              %{
                payload: payload,
                config: config,
                env: env,
                sender: sender
              }}
           ]}
        end
      end

      # Create configuration and environment
      config = State.Configuration.new(nil, :process, %{test_config: true})
      env = State.Environment.new(%{test_env: true}, %{})

      # Execute the action
      result =
        Behaviour.execute_action(
          {:function_handler, TestHandlerModule, :test_handler},
          :test_tag,
          %{test: "payload"},
          {:sender, 1},
          config,
          env
        )

      assert {:ok,
              [
                {:test_effect,
                 %{
                   payload: %{test: "payload"},
                   config: %{test_config: true},
                   env: %{test_env: true},
                   sender: {:sender, 1}
                 }}
              ]} = result
    end

    test "handles function handler errors gracefully" do
      defmodule ErrorHandlerModule do
        def error_handler(_payload, _config, _env, _sender) do
          raise "Test error"
        end
      end

      config = State.Configuration.new(nil, :process, %{})
      env = State.Environment.new(%{}, %{})

      result =
        Behaviour.execute_action(
          {:function_handler, ErrorHandlerModule, :error_handler},
          :test_tag,
          %{},
          nil,
          config,
          env
        )

      assert {:error, {:function_handler_error, _}} = result
    end

    test "handles nil payload correctly" do
      defmodule NilPayloadHandlerModule do
        def nil_handler(payload, _config, _env, _sender) do
          {:ok, [{:received_payload, payload}]}
        end
      end

      config = State.Configuration.new(nil, :process, %{})
      env = State.Environment.new(%{}, %{})

      result =
        Behaviour.execute_action(
          {:function_handler, NilPayloadHandlerModule, :nil_handler},
          :test_tag,
          nil,
          nil,
          config,
          env
        )

      # When payload is nil, the tag should be used as payload
      assert {:ok, [{:received_payload, :test_tag}]} = result
    end
  end

  describe "complete behavior evaluation" do
    test "evaluates complete behavior with matching rule" do
      defmodule CompleteTestModule do
        def ping_handler(_payload, _config, _env, sender) do
          {:ok, [{:send, sender, :pong}]}
        end
      end

      spec = %Spec{
        name: :test_engine,
        version: "1.0.0",
        behaviour_rules: [
          {:ping, {:function_handler, CompleteTestModule, :ping_handler}}
        ],
        interface: [:ping],
        config_spec: %{},
        env_spec: %{},
        message_filter: {:default_filter, []}
      }

      message = Message.new({:sender, 1}, {1, 1}, :ping)
      config = State.Configuration.new(nil, :process, %{})
      env = State.Environment.new(%{}, %{})

      result = Behaviour.evaluate(spec, message, config, env)
      assert {:ok, [{:send, {:sender, 1}, :pong}]} = result
    end

    test "returns noop effect when no rule matches" do
      spec = %Spec{
        name: :test_engine,
        version: "1.0.0",
        behaviour_rules: [
          {:ping, :some_action}
        ],
        interface: [:ping],
        config_spec: %{},
        env_spec: %{},
        message_filter: {:default_filter, []}
      }

      message = Message.new({:sender, 1}, {1, 1}, :unknown_message)
      config = State.Configuration.new(nil, :process, %{})
      env = State.Environment.new(%{}, %{})

      result = Behaviour.evaluate(spec, message, config, env)
      # Should return noop effect when no rule matches
      assert {:ok, effects} = result
      assert length(effects) == 1
    end

    test "handles invalid message format" do
      spec = %Spec{
        name: :test_engine,
        version: "1.0.0",
        behaviour_rules: [],
        interface: [],
        config_spec: %{},
        env_spec: %{},
        message_filter: {:default_filter, []}
      }

      config = State.Configuration.new(nil, :process, %{})
      env = State.Environment.new(%{}, %{})

      # Test with invalid message format
      result = Behaviour.evaluate(spec, "invalid_message", config, env)
      assert {:error, {:invalid_message_format, _}} = result
    end
  end

  describe "rule execution" do
    test "executes rule with Message struct" do
      defmodule RuleTestModule do
        def test_rule_handler(payload, _config, _env, sender) do
          {:ok, [{:executed, payload, sender}]}
        end
      end

      rule = {:test, {:function_handler, RuleTestModule, :test_rule_handler}}
      message = Message.new({:sender, 1}, {1, 1}, {:test, %{data: "value"}})
      config = State.Configuration.new(nil, :process, %{})
      env = State.Environment.new(%{}, %{})

      result = Behaviour.execute_rule(rule, message, config, env)
      assert {:ok, [{:executed, %{data: "value"}, {:sender, 1}}]} = result
    end

    test "executes rule with simple tuple" do
      defmodule SimpleTupleRuleModule do
        def simple_handler(payload, _config, _env, _sender) do
          {:ok, [{:simple_executed, payload}]}
        end
      end

      rule = {:test, {:function_handler, SimpleTupleRuleModule, :simple_handler}}
      config = State.Configuration.new(nil, :process, %{})
      env = State.Environment.new(%{}, %{})

      result = Behaviour.execute_rule(rule, {:test, "simple_payload"}, config, env)
      assert {:ok, [{:simple_executed, "simple_payload"}]} = result
    end

    test "handles unsupported message format in rule execution" do
      rule = {:test, :some_action}
      config = State.Configuration.new(nil, :process, %{})
      env = State.Environment.new(%{}, %{})

      result = Behaviour.execute_rule(rule, "unsupported_format", config, env)
      assert {:error, {:unsupported_message_format, _}} = result
    end
  end
end
