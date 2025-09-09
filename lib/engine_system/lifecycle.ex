defmodule EngineSystem.Lifecycle do
  @moduledoc """
  I handle EngineSystem lifecycle operations.
  """

  @doc """
  I start the EngineSystem application.
  """
  @spec start() :: {:ok, [atom()]} | {:error, any()}
  def start do
    Application.ensure_all_started(:engine_system)
  end

  @doc """
  I stop the EngineSystem application gracefully.
  """
  @spec stop() :: :ok
  def stop do
    Application.stop(:engine_system)
  end

  @doc """
  I reset the EngineSystem application.
  """
  @spec reset() :: {:ok, [atom()]} | {:error, any()}
  def reset do
    stop()
    start()
  end
end
