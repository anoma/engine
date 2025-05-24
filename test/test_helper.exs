ExUnit.start()

# Start the EngineSystem application for tests that need it
case Application.ensure_all_started(:engine_system) do
  {:ok, _} ->
    :ok

  {:error, {:already_started, :engine_system}} ->
    :ok

  {:error, reason} ->
    IO.puts("Warning: Could not start EngineSystem application: #{inspect(reason)}")
end

# Make test helpers available globally
import EngineSystem.TestHelpers
