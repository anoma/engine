defmodule EngineSystem.DSL.CompilationTest do
  use ExUnit.Case, async: true

  describe "DSL Module Structure" do
    test "has required macros defined" do
      # Verify that the DSL module exports the expected macros
      dsl_module = EngineSystem.Engine.DSL

      # Check that the module exists and loads properly
      assert Code.ensure_loaded?(dsl_module)

      # Verify that the module has the __using__ macro by checking module info
      macros = dsl_module.__info__(:macros)
      macro_names = Enum.map(macros, fn {name, _arity} -> name end)

      assert :__using__ in macro_names
      assert :defengine in macro_names
      assert :config in macro_names
      assert :env in macro_names
      assert :messages in macro_names
      assert :message in macro_names
      assert :behaviour in macro_names
      assert :guarded_action in macro_names
    end

    test "can be used in a module without errors" do
      # Test that we can use the DSL in a simple context
      defmodule TestEngineSimple do
        use EngineSystem.Engine.DSL
      end

      # Verify the module was created
      assert Code.ensure_loaded?(TestEngineSimple)
    end

    test "documentation is available" do
      # Test that module docs are accessible
      {:docs_v1, _, _, _, module_doc, _, _} = Code.fetch_docs(EngineSystem.Engine.DSL)

      # Verify module doc exists and contains expected content
      assert module_doc != :hidden
      assert is_map(module_doc) or is_binary(module_doc)
    end
  end

  describe "Compilation Type Structures" do
    test "basic compilation structures exist and work" do
      alias EngineSystem.Engine.Compilation.Types.{
        EngineSpec,
        ConfigSpec,
        EnvSpec,
        MessageInterfaceSpec,
        MessageSpec,
        BehaviourSpec,
        GuardedActionSpec
      }

      # Create basic structures to ensure they work
      config_spec = %ConfigSpec{initial_value_ast: quote(do: %{}), module: nil}
      env_spec = %EnvSpec{initial_value_ast: quote(do: %{}), module: nil}
      message_spec = %MessageSpec{tag: :test, payload_params_ast: [], payload_struct_module: nil}
      message_interface_spec = %MessageInterfaceSpec{messages: [message_spec]}

      guarded_action_spec = %GuardedActionSpec{
        message_tag: :test,
        payload_bindings_ast: quote(do: []),
        context_bindings_ast: quote(do: %{}),
        guard_ast: quote(do: true),
        action_ast: quote(do: [])
      }

      behaviour_spec = %BehaviourSpec{guarded_actions: [guarded_action_spec]}

      engine_spec = %EngineSpec{
        type_name: :TestEngine,
        type_version: "1.0",
        config_spec: config_spec,
        env_spec: env_spec,
        message_interface_spec: message_interface_spec,
        behaviour_spec: behaviour_spec
      }

      # Verify the structure was created successfully
      assert engine_spec.type_name == :TestEngine
      assert engine_spec.type_version == "1.0"
      assert length(engine_spec.message_interface_spec.messages) == 1
      assert length(engine_spec.behaviour_spec.guarded_actions) == 1
    end

    test "complex engine spec compilation" do
      alias EngineSystem.Engine.Compilation.Types.{
        EngineSpec,
        ConfigSpec,
        EnvSpec,
        MessageInterfaceSpec,
        MessageSpec,
        BehaviourSpec,
        GuardedActionSpec
      }

      # Test more complex structures
      config_spec = %ConfigSpec{
        initial_value_ast: quote(do: %{timeout: 5000, retries: 3}),
        module: nil
      }

      env_spec = %EnvSpec{
        initial_value_ast: quote(do: %{counter: 0, history: []}),
        module: nil
      }

      messages = [
        %MessageSpec{tag: :increment, payload_params_ast: [:amount], payload_struct_module: nil},
        %MessageSpec{tag: :decrement, payload_params_ast: [:amount], payload_struct_module: nil},
        %MessageSpec{tag: :reset, payload_params_ast: [], payload_struct_module: nil}
      ]

      message_interface_spec = %MessageInterfaceSpec{messages: messages}

      guarded_actions = [
        %GuardedActionSpec{
          message_tag: :increment,
          payload_bindings_ast: quote(do: [amount]),
          context_bindings_ast: quote(do: %{env: e, config: c}),
          guard_ast: quote(do: amount > 0),
          action_ast: quote(do: [{:update, %{e | counter: e.counter + amount}}])
        },
        %GuardedActionSpec{
          message_tag: :decrement,
          payload_bindings_ast: quote(do: [amount]),
          context_bindings_ast: quote(do: %{env: e, config: c}),
          guard_ast: quote(do: amount > 0 and e.counter >= amount),
          action_ast: quote(do: [{:update, %{e | counter: e.counter - amount}}])
        }
      ]

      behaviour_spec = %BehaviourSpec{guarded_actions: guarded_actions}

      engine_spec = %EngineSpec{
        type_name: :ComplexEngine,
        type_version: "2.0",
        config_spec: config_spec,
        env_spec: env_spec,
        message_interface_spec: message_interface_spec,
        behaviour_spec: behaviour_spec
      }

      # Verify the complex structure
      assert engine_spec.type_name == :ComplexEngine
      assert engine_spec.type_version == "2.0"
      assert length(engine_spec.message_interface_spec.messages) == 3
      assert length(engine_spec.behaviour_spec.guarded_actions) == 2
    end
  end

  describe "DSL Registration Process" do
    test "engine registration callback works" do
      # This tests the after_compile callback mechanism
      defmodule TestEngineRegistration do
        use EngineSystem.Engine.DSL

        defengine TestRegistrationEngine, version: "1.0", do: (
          config do
            %{test: true}
          end

          env do
            %{state: :initial}
          end

          messages do
            message(:ping, params: [])
          end

          behaviour do
            guarded_action :ping, [], env: e, do: [
              {:send, sender, {:pong}}
            ]
          end
        )
      end

      # Verify the engine was compiled and has the expected methods
      assert function_exported?(TestEngineRegistration, :__engine_spec__, 0)
      assert function_exported?(TestEngineRegistration, :__engine_definition_module__, 0)

      spec = TestEngineRegistration.__engine_spec__()
      assert spec.type_name == TestRegistrationEngine
      assert spec.type_version == "1.0"
    end
  end
end
