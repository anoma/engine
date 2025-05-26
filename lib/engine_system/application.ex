defmodule EngineSystem.Application do
  @moduledoc """
  I implement the Application behaviour for the EngineSystem.

  This module handles application-level configuration and lifecycle,
  starting and stopping the main application supervisor.

  ## Public API

  This module implements the OTP Application behaviour callbacks:

  - `start/2` - Start the application and its supervision tree
  - `stop/1` - Stop the application and clean up resources

  These functions are called automatically by the OTP application controller
  and should not be called directly by user code. To start/stop the system,
  use `EngineSystem.start/0` and `EngineSystem.stop/0` instead.
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
