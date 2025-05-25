defmodule EngineSystem.Lifecycle do
  @moduledoc """
  I handle the lifecycle operations for the EngineSystem.

  I manage:
  - Starting and stopping the system
  - Application lifecycle management
  - System initialization and cleanup

  ## Public API

  - `start/0` - Start the EngineSystem application
  - `stop/0` - Stop the EngineSystem application
  - `reset/0` - Reset the EngineSystem application (stop then start)
  """

  @doc """
  I start the EngineSystem application.

  This starts the OTP application with all necessary supervisors and services.

  ## Returns

  - `{:ok, pid}` if the system started successfully
  - `{:error, reason}` if startup failed
  """
  @spec start() :: {:ok, pid()} | {:error, any()}
  def start do
    Application.ensure_all_started(:engine_system)
  end

  @doc """
  I stop the EngineSystem application.

  ## Returns

  `:ok` when the system has been stopped.
  """
  @spec stop() :: :ok
  def stop do
    Application.stop(:engine_system)
  end

  @doc """
  I reset the EngineSystem application.

  This stops the system and then starts it again, effectively restarting
  all supervisors and services with a clean state.

  ## Returns

  - `{:ok, pid}` if the system reset successfully
  - `{:error, reason}` if reset failed
  """
  @spec reset() :: {:ok, pid()} | {:error, any()}
  def reset do
    stop()
    start()
  end
end
