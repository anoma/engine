defmodule EngineSystem.TestHelpers do
  @moduledoc """
  Common test utilities and helpers for EngineSystem tests.
  """

  import ExUnit.Assertions

  @doc """
  Waits for engine registration to complete.
  """
  def wait_for_registration(timeout \\ 200) do
    Process.sleep(timeout)
  end

  @doc """
  Creates a simple test engine definition.
  """
  defmacro simple_test_engine(name, version \\ "1.0") do
    quote do
      defmodule unquote(Module.concat([__CALLER__.module, name])) do
        use EngineSystem.Engine.DSL

        defengine unquote(name), version: unquote(version) do
          config do
            %{test: true}
          end

          env do
            %{data: %{}}
          end

          messages do
            message(:ping, params: [])
            message(:echo, params: [:msg])
          end

          behaviour do
            guarded_action :ping, [], env: e do
              [{:send, sender, {:pong}}]
            end

            guarded_action :echo, [msg], env: e do
              [{:send, sender, {:echo_response, msg}}]
            end
          end
        end
      end
    end
  end

  @doc """
  Creates a key-value store engine for testing.
  """
  defmacro kv_store_engine(name, version \\ "1.0") do
    quote do
      defmodule unquote(Module.concat([__CALLER__.module, name])) do
        use EngineSystem.Engine.DSL

        defengine unquote(name), version: unquote(version) do
          config do
            %{read_only: false}
          end

          env do
            %{store: %{}, access_count: %{}}
          end

          messages do
            message(:put, params: [:key, :value])
            message(:get, params: [:key])
            message(:delete, params: [:key])
            message(:size, params: [])
          end

          behaviour do
            guarded_action :put, [key, value], env: e, config: c, when: not c.read_only do
              [
                {:update,
                 %{
                   e
                   | store: Map.put(e.store, key, value),
                     access_count: Map.update(e.access_count, key, 1, &(&1 + 1))
                 }},
                {:send, sender, {:ok, :stored}}
              ]
            end

            guarded_action :get, [key], env: e do
              value = Map.get(e.store, key)
              new_count = Map.update(e.access_count, key, 1, &(&1 + 1))

              [
                {:update, %{e | access_count: new_count}},
                {:send, sender, {:result, value}}
              ]
            end

            guarded_action :delete, [key], env: e, config: c, when: not c.read_only do
              [
                {:update, %{e | store: Map.delete(e.store, key)}},
                {:send, sender, {:ok, :deleted}}
              ]
            end

            guarded_action :size, [], env: e do
              size = map_size(e.store)
              access_total = e.access_count |> Map.values() |> Enum.sum()

              [
                {:send, sender, {:stats, size, access_total}}
              ]
            end
          end
        end
      end
    end
  end

  @doc """
  Asserts that an engine type is properly registered.
  """
  def assert_engine_registered(type_name, version) do
    case EngineSystem.System.Services.get_engine_type_info(type_name, version) do
      %{status: :ok, value: type_info} ->
        assert type_info.name == type_name
        assert type_info.version == version
        type_info

      error ->
        flunk("Engine type #{type_name} v#{version} not registered: #{inspect(error)}")
    end
  end

  @doc """
  Creates an engine instance and returns its address.
  """
  def create_test_engine(type_name, version, config \\ %{}) do
    default_config = %{read_only: false, parent: nil, mode: :process}
    final_config = Map.merge(default_config, config)

    case EngineSystem.System.Services.create_engine_instance({type_name, version}, final_config) do
      %{status: :ok, value: address} -> address
      error -> flunk("Failed to create engine: #{inspect(error)}")
    end
  end

  @doc """
  Sends a message to an engine and asserts success.
  """
  def send_test_message(address, message) do
    case EngineSystem.System.Services.send_message(address, message) do
      %{status: :ok} = result -> result
      error -> flunk("Failed to send message: #{inspect(error)}")
    end
  end

  @doc """
  Asserts that the system has at least the expected number of engines.
  """
  def assert_engine_count_at_least(expected_count) do
    case EngineSystem.System.Services.list_engine_instances() do
      %{status: :ok, value: engine_list} ->
        actual_count = length(engine_list)

        assert actual_count >= expected_count,
               "Expected at least #{expected_count} engines, but found #{actual_count}"

        engine_list

      error ->
        flunk("Failed to list engines: #{inspect(error)}")
    end
  end

  @doc """
  Generates a unique test name with a timestamp.
  """
  def unique_test_name(prefix \\ "Test") do
    timestamp = System.unique_integer([:positive])
    String.to_atom("#{prefix}#{timestamp}")
  end
end
