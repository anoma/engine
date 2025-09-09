defmodule EngineSystem.Supervisor do
  @moduledoc """
  I am the root supervisor for the EngineSystem.
  """

  use Supervisor

  alias EngineSystem.System.Registry

  @doc """
  I start the supervisor.
  """
  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      # System Registry - tracks engine specs and instances
      {Registry, name: EngineSystem.System.Registry},

      # Dynamic Supervisor for Engine Instances
      {DynamicSupervisor, name: EngineSystem.Engine.DynamicSupervisor, strategy: :one_for_one},

      # Dynamic Supervisor for Mailbox Engines
      {DynamicSupervisor, name: EngineSystem.Mailbox.DynamicSupervisor, strategy: :one_for_one}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
