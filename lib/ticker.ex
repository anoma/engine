defmodule Ticker do
  @moduledoc """
  A simple ticker engine.
  """
  use Engine, strict: false, debug: true

  # Message interface (MI)
  # Recall, the Ticker's MI is the only language the Ticker engines speaks. It
  # must include what types of messages the engine can read and write.

  # requests ------------
  defmsg(:tick)
  defmsg(:get_count)
  # responses ------------
  defmsg(:count, :integer)

  # Execution environment
  defconfig(
    %{name: "Ticker"}
  )

  # TODO: Guards

  # TODO: Effects
end
