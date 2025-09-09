defmodule EngineSystem.Application do
  @moduledoc """
  I implement the Application behaviour for the EngineSystem.
  """

  use Application

  alias EngineSystem.Supervisor

  @impl true
  def start(_type, _args) do
    Supervisor.start_link([])
  end

  @impl true
  def stop(_state) do
    :ok
  end
end
