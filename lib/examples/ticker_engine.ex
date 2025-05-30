import EngineSystem.Engine.DSL

defengine Examples.TickerEngine do
  @moduledoc "Simple ticker that increments a counter."

  version("1.0.0")

  interface do
    message(:tick)
    message(:get_count)
    message(:reset)
    message(:count_response, value: :integer)
  end

  config do
    %{max_value: 100}
  end

  env do
    %{count: 0}
  end

  message_filter(fn _msg, _config, _env -> true end)

  behaviour do
    on_message :tick, _msg_payload, config, env, _sender do
      count = env.count
      max = config.max_value
      new_count = if count >= max, do: 0, else: count + 1
      new_env = %{env | count: new_count}
      {:ok, [{:update_environment, new_env}]}
    end

    on_message :get_count, _msg_payload, _config, env, sender do
      {:ok, [{:send, sender, {:count_response, env.count}}]}
    end

    on_message :reset, _msg_payload, _config, env, _sender do
      new_env = %{env | count: 0}
      {:ok, [{:update_environment, new_env}]}
    end
  end
end
