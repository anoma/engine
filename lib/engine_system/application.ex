defmodule EngineSystem.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the message router for mailbox-processing engine communication
      EngineSystem.MessagePassing.Router,
      # Start the system services supervisor
      EngineSystem.System.Services
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: EngineSystem.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
