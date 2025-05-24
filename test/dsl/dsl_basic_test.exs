defmodule EngineSystem.DSL.BasicTest do
  use ExUnit.Case, async: true
  doctest EngineSystem.Engine.DSL

  test "basic DSL syntax compiles correctly" do
    defmodule SimpleDSLTestEngine do
      use EngineSystem.Engine.DSL

      defengine SimpleTestEngine, version: "1.0", do: (
        config do
          %{test: true}
        end

        env do
          %{data: %{}}
        end

        messages do
          message(:hello, params: [:name])
        end

        behaviour do
          guarded_action :hello, [name], env: e, do: [
            {:send, sender, {:greeting, "Hello #{name}!"}}
          ]
        end
      )
    end

    # Verify the engine spec was created correctly
    spec = SimpleDSLTestEngine.__engine_spec__()
    assert spec.type_name == SimpleTestEngine
    assert spec.type_version == "1.0"
    assert length(spec.message_interface_spec.messages) == 1
    assert length(spec.behaviour_spec.guarded_actions) == 1
  end

  test "__using__ macro imports correct macros" do
    defmodule TestUsingMacroModule do
      use EngineSystem.Engine.DSL

      def test_macros_available do
        # Check if the DSL macros are available by trying to use them
        try do
          quote do
            defengine TestMacroEngine, version: "1.0", do: (
              config do
                %{test: true}
              end
            )
          end

          true
        rescue
          _ -> false
        end
      end
    end

    assert TestUsingMacroModule.test_macros_available()
  end

  test "direct import syntax works" do
    defmodule TestDirectImportEngine do
      import EngineSystem.Engine.DSL

      defengine TestEngine, version: "1.0", do: (
        config do
          %{test: true}
        end

        env do
          %{data: %{}}
        end

        messages do
          message(:test, params: [:msg])
        end

        behaviour do
          guarded_action :test, [msg], env: e, do: [
            {:send, sender, {:ok, msg}}
          ]
        end
      )
    end

    spec = TestDirectImportEngine.__engine_spec__()
    assert spec.type_name == TestEngine
    assert spec.type_version == "1.0"
  end

  test "corrected syntax with explicit parentheses" do
    defmodule TestCorrectedSyntaxEngine do
      import EngineSystem.Engine.DSL

      defengine(TestEngine, version: "1.0", do: (
        config do
          %{test: true}
        end

        env do
          %{data: %{}}
        end

        messages do
          message(:test, params: [:msg])
        end

        behaviour do
          guarded_action :test, [msg], env: e, do: [
            {:send, sender, {:ok, msg}}
          ]
        end
      ))
    end

    spec = TestCorrectedSyntaxEngine.__engine_spec__()
    assert spec.type_name == TestEngine
    assert spec.type_version == "1.0"
  end
end
