defmodule EngineTest do
  use ExUnit.Case
  doctest Engine

  test "raises error when no message types defined" do
    assert_raise CompileError, ~r/An engine must define at least one message type/, fn ->
      defmodule EmptyEngine do
        use Engine
      end
    end
  end

  test "raises error when message type already defined" do
    assert_raise CompileError, ~r/Message tag <tick> already defined/, fn ->
      defmodule DuplicateMessageType do
        use Engine
        defmsg(:tick)
        defmsg(:tick)
      end
    end
  end

  test "Check the message tags are registered" do
    defmodule NormalSyntax do
      use Engine
      defmsg(:tick)
      defmsg(:stop)
      defmsg(:start, %{id: :integer})
    end

    assert MapSet.equal?(
             MapSet.new(NormalSyntax.message_tags()),
             MapSet.new([:tick, :stop, :start])
           )
  end
end
