defmodule Ticker do
  @moduledoc """
  A simple ticker engine.
  """
  use Engine

  # Message interface
  defmsg(:tick)
  defmsg(:get_count)

  # TODO: Guard

  # TODO: Effects
end
