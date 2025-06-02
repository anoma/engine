use EngineSystem

defengine Examples.KVStoreEngine do
  @moduledoc "Simple key-value store engine."

  version("1.0.0")
  # This is a processing engine
  mode(:process)

  interface do
    message(:put, key: :atom, value: :any)
    message(:get, key: :atom)
    message(:delete, key: :atom)
    message(:result, value: :any)
    message(:ack)
  end

  env do
    %{store: %{}, access_counts: %{}}
  end

  behaviour do
    on_message :put, %{key: key, value: value}, _config, env, sender do
      new_store = Map.put(env.store, key, value)
      new_env = %{env | store: new_store}
      {:ok, [{:update_environment, new_env}, {:send, sender, :ack}]}
    end

    on_message :get, %{key: key}, _config, env, sender do
      value = Map.get(env.store, key)
      {:ok, [{:send, sender, {:result, value}}]}
    end

    on_message :delete, %{key: key}, _config, env, sender do
      new_store = Map.delete(env.store, key)
      new_env = %{env | store: new_store}
      {:ok, [{:update_environment, new_env}, {:send, sender, :ack}]}
    end
  end
end
