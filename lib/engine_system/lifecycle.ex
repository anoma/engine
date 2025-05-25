defmodule EngineSystem.Lifecycle do
  @moduledoc """
  I handle the lifecycle operations for the EngineSystem.

  I manage:
  - Starting and stopping the system
  - Application lifecycle management
  - System initialization and cleanup
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
end
