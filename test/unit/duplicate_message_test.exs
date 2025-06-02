defmodule EngineSystem.Unit.DuplicateMessageTest do
  use ExUnit.Case, async: true

  describe "duplicate message tag detection" do
    test "should raise compilation error for duplicate message tags" do
      assert_raise CompileError, ~r/duplicate message tag/, fn ->
        defmodule TestEngineWithDuplicates do
          import EngineSystem.Engine.DSL

          defengine TestEngineWithDuplicates do
            version "1.0.0"
            mode :process

            interface do
              message :get, key: :binary
              message :put, key: :binary, value: :any
              message :get, id: :integer  # Duplicate tag - should be an error!
              message :delete, key: :binary
            end
          end
        end
      end
    end

    test "should accept unique message tags without error" do
      # This should compile without any errors
      defmodule TestEngineWithUniqueMessages do
        import EngineSystem.Engine.DSL

        defengine TestEngineWithUniqueMessages do
          version "1.0.0"
          mode :process

          interface do
            message :get, key: :binary
            message :put, key: :binary, value: :any
            message :delete, key: :binary
            message :list
          end
        end
      end

      # If we get here, compilation succeeded
      assert true
    end

    test "should provide detailed error message with line numbers" do
      exception = assert_raise CompileError, fn ->
        defmodule TestEngineWithDetailedDuplicate do
          import EngineSystem.Engine.DSL

          defengine TestEngineWithDetailedDuplicate do
            version "1.0.0"
            mode :process

            interface do
              message :user_action, type: :create
              message :user_action, type: :update  # This should provide line info
            end
          end
        end
      end

      # Check that the error message contains useful information
      assert exception.description =~ "duplicate message tag :user_action"
      assert exception.description =~ "First definition at"
      assert exception.description =~ "Duplicate definition at"
      assert exception.description =~ "Suggestion:"
    end
  end
end
