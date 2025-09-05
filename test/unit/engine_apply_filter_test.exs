defmodule EngineSystem.Unit.EngineApplyFilterTest do
  use ExUnit.Case, async: true

  alias EngineSystem.Engine

  describe "apply_filter/2" do
    test "supports 1-arity filters" do
      filter = fn {:msg, n} -> n > 0 end

      assert Engine.apply_filter(filter, {:msg, 1}) == true
      assert Engine.apply_filter(filter, {:msg, 0}) == false
    end

    test "supports 3-arity filters (msg, _config, _env)" do
      filter = fn {:msg, n}, _config, _env -> rem(n, 2) == 0 end

      assert Engine.apply_filter(filter, {:msg, 2}) == true
      assert Engine.apply_filter(filter, {:msg, 3}) == false
    end

    test "returns false when filter crashes" do
      bad_filter = fn _ -> raise "boom" end

      assert Engine.apply_filter(bad_filter, :anything) == false
    end
  end
end
