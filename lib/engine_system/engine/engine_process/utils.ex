defmodule EngineSystem.Engine.EngineProcess.Utils do
  @moduledoc """
  I provide utility functions for the EngineProcess module.

  I handle:
  - Engine address generation
  - Message ID generation
  - Sender address extraction
  - Environment initialization
  """

  alias EngineSystem.Engine.EngineProcess.Types

  @doc """
  I generate a unique address for an engine instance.
  """
  @spec generate_engine_address() :: Types.engine_address()
  def generate_engine_address do
    # Generate a unique address for this engine instance
    # In a real system, this would follow a more structured format
    # such as {:engine, node(), System.unique_integer([:positive])}
    {:engine, node(), System.unique_integer([:positive])}
  end

  @doc """
  I generate a unique message ID.
  """
  @spec generate_message_id() :: Types.message_id()
  def generate_message_id do
    # Generate a unique message ID
    # Try to use UUID if available, otherwise fallback to unique integer
    case Code.ensure_loaded(UUID) do
      {:module, UUID} ->
        try do
          UUID.uuid4()
        rescue
          _ -> fallback_message_id()
        end

      {:error, _} ->
        fallback_message_id()
    end
  end

  @doc """
  I extract the sender address from a GenServer.from() tuple.
  """
  @spec extract_sender_address(GenServer.from()) :: Types.engine_address()
  def extract_sender_address({pid, _tag}) do
    # Try to get the engine address from the sender's PID
    # In a real system, this would use a registry or process dictionary
    # to look up the engine address for a given PID
    {:sender, pid}
  end

  @doc """
  I initialize the environment from an environment specification.
  """
  @spec initialize_environment(any()) :: Types.environment()
  def initialize_environment(env_spec) do
    # Evaluate the initial environment expression
    {env, _} = Code.eval_quoted(env_spec.initial_value_ast)
    env
  end

  # --- Private Functions --- #

  @spec fallback_message_id() :: Types.message_id()
  defp fallback_message_id do
    "msg-#{System.unique_integer([:positive])}-#{System.system_time(:millisecond)}"
  end
end
