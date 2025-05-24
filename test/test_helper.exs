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

# Note: TestHelpers import removed as it was unused
# Can be re-added when test helper functions are needed
