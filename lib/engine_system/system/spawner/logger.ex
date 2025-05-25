defmodule EngineSystem.System.Spawner.Logger do
  @moduledoc """
  I provide structured logging for engine spawning operations.

  This module centralizes all logging related to the s-EngineSpawn operational rule,
  providing consistent, readable, and structured log messages for debugging and
  monitoring engine lifecycle events.

  ## Logging Categories

  - **Registration Events**: Success and failure of engine instance registration
  - **Spawning Events**: Engine and mailbox creation events
  - **Validation Events**: Input validation failures
  - **System Events**: General spawner state and statistics

  ## Log Levels

  - **Info**: Successful operations and normal system events
  - **Error**: Failed operations with detailed context
  - **Debug**: Detailed operational information (when enabled)
  - **Warn**: Non-fatal issues that should be monitored

  ## Usage

      iex> alias EngineSystem.System.Spawner.Logger, as: SpawnerLogger
      iex> SpawnerLogger.log_successful_registration(address, spec, engine_pid, mailbox_pid, name)
      :ok

  ## Log Format

  All logs follow a structured format with:
  - Clear operation description
  - Formatted addresses (node:X/engine:Y)
  - Relevant context (PIDs, specs, names)
  - Human-readable error descriptions
  """

  alias EngineSystem.Engine.{Spec, State}
  alias EngineSystem.System.Spawner.Validator

  require Logger

  @doc """
  I log successful engine instance registration.

  ## Parameters

  - `address` - The engine's address
  - `spec` - The engine specification
  - `engine_pid` - The engine process PID
  - `mailbox_pid` - The mailbox process PID
  - `name` - Optional instance name

  ## Examples

      iex> SpawnerLogger.log_successful_registration({1, 123}, spec, pid1, pid2, :my_engine)
      :ok
  """
  @spec log_successful_registration(State.address(), Spec.t(), pid(), pid(), atom() | nil) :: :ok
  def log_successful_registration(address, spec, engine_pid, mailbox_pid, name) do
    name_info = format_name_info(name)
    address_str = format_address(address)

    Logger.info("""
    Spawner: Successfully registered engine instance#{name_info}
    Address: #{address_str}
    Spec: #{spec.name} v#{spec.version}
    Engine PID: #{inspect(engine_pid)}
    Mailbox PID: #{inspect(mailbox_pid)}
    """)
  end

  @doc """
  I log failed engine instance registration with detailed context.

  ## Parameters

  - `address` - The engine's address
  - `spec` - The engine specification
  - `engine_pid` - The engine process PID
  - `mailbox_pid` - The mailbox process PID
  - `name` - Optional instance name
  - `reason` - The failure reason

  ## Examples

      iex> SpawnerLogger.log_registration_failure(address, spec, pid1, pid2, :my_engine, :name_already_taken)
      :ok
  """
  @spec log_registration_failure(State.address(), Spec.t(), pid(), pid(), atom() | nil, atom()) ::
          :ok
  def log_registration_failure(address, spec, engine_pid, mailbox_pid, name, reason) do
    address_str = format_address(address)
    name_str = format_name_for_error(name)
    reason_str = Validator.describe_error(reason)

    Logger.error("""
    Spawner: Failed to register engine instance
    Address: #{address_str}
    Spec: #{spec.name} v#{spec.version}
    Engine PID: #{inspect(engine_pid)}
    Mailbox PID: #{inspect(mailbox_pid)}
    Name: #{name_str}
    Reason: #{reason_str}
    """)
  end

  @doc """
  I log the start of an engine spawning operation.

  ## Parameters

  - `engine_module` - The engine module being spawned
  - `config` - The engine configuration
  - `environment` - The engine environment
  - `name` - Optional instance name

  ## Examples

      iex> SpawnerLogger.log_spawn_start(MyEngine, %{}, %{}, :my_instance)
      :ok
  """
  @spec log_spawn_start(module(), any(), any(), atom() | nil) :: :ok
  def log_spawn_start(engine_module, config, environment, name) do
    name_info = format_name_info(name)
    config_summary = summarize_config(config)
    env_summary = summarize_environment(environment)

    Logger.info("""
    Spawner: Starting engine spawn operation#{name_info}
    Module: #{engine_module}
    Config: #{config_summary}
    Environment: #{env_summary}
    """)
  end

  @doc """
  I log successful completion of an engine spawning operation.

  ## Parameters

  - `address` - The newly created engine's address
  - `engine_module` - The engine module that was spawned
  - `name` - Optional instance name

  ## Examples

      iex> SpawnerLogger.log_spawn_success({1, 123}, MyEngine, :my_instance)
      :ok
  """
  @spec log_spawn_success(State.address(), module(), atom() | nil) :: :ok
  def log_spawn_success(address, engine_module, name) do
    name_info = format_name_info(name)
    address_str = format_address(address)

    Logger.info("""
    Spawner: Successfully completed engine spawn operation#{name_info}
    Module: #{engine_module}
    Address: #{address_str}
    """)
  end

  @doc """
  I log failed engine spawning operation.

  ## Parameters

  - `engine_module` - The engine module that failed to spawn
  - `reason` - The failure reason
  - `name` - Optional instance name

  ## Examples

      iex> SpawnerLogger.log_spawn_failure(MyEngine, :invalid_spec, :my_instance)
      :ok
  """
  @spec log_spawn_failure(module(), any(), atom() | nil) :: :ok
  def log_spawn_failure(engine_module, reason, name) do
    name_info = format_name_info(name)
    reason_str = format_spawn_failure_reason(reason)

    Logger.error("""
    Spawner: Failed to spawn engine#{name_info}
    Module: #{engine_module}
    Reason: #{reason_str}
    """)
  end

  @doc """
  I log validation failures with detailed context.

  ## Parameters

  - `validation_type` - The type of validation that failed
  - `reason` - The validation failure reason
  - `context` - Additional context about the failure

  ## Examples

      iex> SpawnerLogger.log_validation_failure(:address, :invalid_format, %{address: "bad"})
      :ok
  """
  @spec log_validation_failure(atom(), atom(), map()) :: :ok
  def log_validation_failure(validation_type, reason, context \\ %{}) do
    reason_str = Validator.describe_error(reason)
    context_str = format_validation_context(context)

    Logger.error("""
    Spawner: Validation failure
    Type: #{validation_type}
    Reason: #{reason_str}
    Context: #{context_str}
    """)
  end

  @doc """
  I log spawner statistics and system information.

  ## Parameters

  - `stats` - A map containing spawner statistics

  ## Examples

      iex> stats = %{active_engines: 5, total_spawned: 10, failures: 1}
      iex> SpawnerLogger.log_spawner_stats(stats)
      :ok
  """
  @spec log_spawner_stats(map()) :: :ok
  def log_spawner_stats(stats) do
    Logger.info("""
    Spawner: System statistics
    Active engines: #{Map.get(stats, :active_engines, "unknown")}
    Total spawned: #{Map.get(stats, :total_spawned, "unknown")}
    Failures: #{Map.get(stats, :failures, "unknown")}
    Success rate: #{calculate_success_rate(stats)}
    """)
  end

  ## Private Helper Functions

  # Format address for better readability in logs
  @spec format_address(State.address()) :: String.t()
  defp format_address({node_id, engine_id}) do
    "node:#{node_id}/engine:#{engine_id}"
  end

  defp format_address(address) do
    # Fallback for malformed addresses
    "invalid:#{inspect(address)}"
  end

  # Format name information for log messages
  @spec format_name_info(atom() | nil) :: String.t()
  defp format_name_info(nil), do: ""
  defp format_name_info(name), do: " with name '#{name}'"

  # Format name for error messages
  @spec format_name_for_error(atom() | nil) :: String.t()
  defp format_name_for_error(nil), do: "none"
  defp format_name_for_error(name), do: "#{name}"

  # Summarize configuration for logging
  @spec summarize_config(any()) :: String.t()
  defp summarize_config(nil), do: "default"

  defp summarize_config(config) when is_map(config) do
    keys = Map.keys(config)
    "#{length(keys)} keys: #{inspect(keys)}"
  end

  defp summarize_config(config), do: "#{inspect(config)}"

  # Summarize environment for logging
  @spec summarize_environment(any()) :: String.t()
  defp summarize_environment(nil), do: "default"

  defp summarize_environment(env) when is_map(env) do
    keys = Map.keys(env)
    "#{length(keys)} keys: #{inspect(keys)}"
  end

  defp summarize_environment(env), do: "#{inspect(env)}"

  # Format spawn failure reasons
  @spec format_spawn_failure_reason(any()) :: String.t()
  defp format_spawn_failure_reason({:invalid_engine_module, module}) do
    "Invalid engine module: #{module}"
  end

  defp format_spawn_failure_reason({:spec_error, error}) do
    "Spec error: #{inspect(error)}"
  end

  defp format_spawn_failure_reason({:mailbox_start_failed, reason}) do
    "Mailbox start failed: #{inspect(reason)}"
  end

  defp format_spawn_failure_reason({:engine_start_failed, reason}) do
    "Engine start failed: #{inspect(reason)}"
  end

  defp format_spawn_failure_reason(reason) do
    "#{inspect(reason)}"
  end

  # Format validation context for logging
  @spec format_validation_context(map()) :: String.t()
  defp format_validation_context(context) when map_size(context) == 0, do: "none"

  defp format_validation_context(context) do
    Enum.map_join(context, ", ", fn {key, value} -> "#{key}: #{inspect(value)}" end)
  end

  # Calculate success rate from statistics
  @spec calculate_success_rate(map()) :: String.t()
  defp calculate_success_rate(stats) do
    total = Map.get(stats, :total_spawned, 0)
    failures = Map.get(stats, :failures, 0)

    if total > 0 do
      success_rate = ((total - failures) / total * 100) |> Float.round(1)
      "#{success_rate}%"
    else
      "N/A"
    end
  end
end
