#!/usr/bin/env elixir

# Test DSL syntax

defmodule TestDSLSyntax do
  use EngineSystem.Engine.DSL

  # Try the syntax without version first
  defengine TestEngine do
    config do
      %{test: true}
    end

    env do
      %{data: %{}}
    end

    messages do
      message :hello, params: [:name]
    end

    behaviour do
      guarded_action :hello, [name], env: e, do: [
        {:send, sender, {:greeting, "Hello #{name}!"}}
      ]
    end
  end
end

IO.puts("Engine spec: #{inspect(TestDSLSyntax.__engine_spec__())}")
