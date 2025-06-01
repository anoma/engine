defmodule SimpleExample do
  @moduledoc """
  I demonstrate the clean and simple `use EngineSystem` interface.

  This single import gives you everything you need:
  - DSL macros for defining engines
  - Utility functions for message processing
  - API functions for system management and communication

  ## Before (multiple imports needed):
  ```elixir
  use EngineSystem.Engine           # For DSL
  import EngineSystem, only: [...]  # For API functions
  ```

  ## After (single import):
  ```elixir
  use EngineSystem  # Everything you need!
  ```
  """

  # This single line gives us access to:
  # - DSL macros: defengine, version, config, env, interface, behaviour, etc.
  # - Utility functions: validate_message_for_pe/2, extract_messages/3, etc.
  # - API functions: spawn_engine/1, send_message/2, start/0, etc.
  use EngineSystem

  # Define a simple counter engine using the DSL
  defengine SimpleCounter do
    version("1.0.0")
    mode(:process)

    config do
      %{
        max_count: 100,
        step: 1
      }
    end

    env do
      %{
        count: 0,
        total_operations: 0
      }
    end

    interface do
      message(:increment)
      message(:decrement)
      message(:get_count)
      message(:reset)
      message(:count_response, [:value])
    end

    behaviour do
      on_message :increment, _msg, config, env, sender do
        new_count = min(env.count + config.step, config.max_count)
        new_env = %{env | count: new_count, total_operations: env.total_operations + 1}

        {:ok,
         [
           {:update_environment, new_env},
           {:send, sender, {:count_response, new_count}}
         ]}
      end

      on_message :decrement, _msg, config, env, sender do
        new_count = max(env.count - config.step, 0)
        new_env = %{env | count: new_count, total_operations: env.total_operations + 1}

        {:ok,
         [
           {:update_environment, new_env},
           {:send, sender, {:count_response, new_count}}
         ]}
      end

      on_message :get_count, _msg, _config, env, sender do
        {:ok, [{:send, sender, {:count_response, env.count}}]}
      end

      on_message :reset, _msg, _config, env, sender do
        new_env = %{env | count: 0, total_operations: env.total_operations + 1}

        {:ok,
         [
           {:update_environment, new_env},
           {:send, sender, {:count_response, 0}}
         ]}
      end
    end
  end

  @doc """
  I demonstrate how to use the engine with all API functions available directly.
  """
  def demo do
    # Start the system (API function directly available)
    {:ok, _} = start()

    # Spawn our counter engine (API function directly available)
    {:ok, counter_address} = spawn_engine(SimpleCounter)

    # Send some messages (API function directly available)
    :ok = send_message(counter_address, {:increment, %{}})
    :ok = send_message(counter_address, {:increment, %{}})
    :ok = send_message(counter_address, {:get_count, %{}})

    # Check system status (API function directly available)
    info = get_system_info()
    IO.inspect(info, label: "System Info")

    # List running instances (API function directly available)
    instances = list_instances()
    IO.inspect(instances, label: "Running Instances")

    # Clean up (API function directly available)
    :ok = terminate_engine(counter_address)
  end

  @doc """
  I demonstrate utility functions that are also directly available.
  """
  def demo_utilities do
    # Generate unique IDs (utility function directly available)
    id = fresh_id()
    IO.inspect(id, label: "Fresh ID")

    # Validate addresses (utility function directly available)
    case validate_address({0, 123}) do
      :ok -> IO.puts("Valid address")
      {:error, reason} -> IO.puts("Invalid address: #{reason}")
    end

    # Extract message tags (utility function directly available)
    case extract_message_tag({:increment, %{}}) do
      {:ok, tag} -> IO.inspect(tag, label: "Message tag")
      {:error, reason} -> IO.puts("Could not extract tag: #{reason}")
    end
  end
end
