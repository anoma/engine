defmodule DSLCompileTimeTest do
  use ExUnit.Case
  import EngineSystem.Engine.DSL

  # Define the test engine at module level
  defengine TestEngine.CompileTimeValidation do
    version("1.0.0")

    interface do
      message(:test_message, value: :integer)
    end

    config do
      %{max_value: 100}
    end

    env do
      %{counter: 0}
    end

    message_filter(fn _msg, _config, _env -> true end)

    behaviour do
      on_message :test_message, %{value: value}, config, env, sender do
        # This will be validated at compile time!
        new_counter = env.counter + value
        max = config.max_value

        if new_counter > max do
          {:ok, [{:send, sender, {:error, :value_too_large}}]}
        else
          new_env = %{env | counter: new_counter}
          {:ok, [{:update_environment, new_env}, {:send, sender, {:ok, new_counter}}]}
        end
      end
    end
  end

  test "function-based handlers compile successfully" do
    # If we get here, compilation succeeded
    assert true
  end

  test "engine spec is created correctly with function handlers" do
    spec = TestEngine.CompileTimeValidation.__engine_spec__()

    assert spec.name == TestEngine.CompileTimeValidation
    assert spec.version == "1.0.0"
    assert length(spec.behaviour_rules) == 1

    {tag, handler} = List.first(spec.behaviour_rules)
    assert tag == :test_message
    assert match?({:function_handler, TestEngine.CompileTimeValidation, _}, handler)
  end
end
