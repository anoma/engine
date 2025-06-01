use EngineSystem

defengine Examples.SimpleCounterEngine do
  @moduledoc """
  A simple counter engine that demonstrates simplified environment syntax.
  This engine maintains a counter that can be incremented, decremented, and reset.
  """

  version("2.0.0")
  # This is a processing engine
  mode(:process)

  interface do
    message(:increment)
    message(:decrement)
    message(:reset)
    message(:get_count)
    message(:add, value: :integer)
  end

  config do
    %{
      mode: :unlimited,
      auto_reset: false,
      notifications: true
    }
  end

  env do
    %{
      counter: 0,
      increment_by: 1,
      max_count: 100,
      enabled: true,
      history: [],
      metadata: %{}
    }
  end

  behaviour do
    on_message :increment, _payload, config, env, sender do
      if env.enabled do
        new_counter = env.counter + env.increment_by

        if config.mode == :limited and new_counter > env.max_count do
          {:ok, [{:send, sender, {:error, :max_count_reached}}]}
        else
          new_env = %{env | counter: new_counter, history: [env.counter | env.history]}

          response =
            if config.notifications,
              do: {:count_updated, new_counter},
              else: {:ok, new_counter}

          {:ok, [{:update_environment, new_env}, {:send, sender, response}]}
        end
      else
        {:ok, [{:send, sender, {:error, :counter_disabled}}]}
      end
    end

    on_message :decrement, _payload, _config, env, sender do
      if env.enabled do
        new_counter = max(0, env.counter - env.increment_by)
        new_env = %{env | counter: new_counter, history: [env.counter | env.history]}
        {:ok, [{:update_environment, new_env}, {:send, sender, {:ok, new_counter}}]}
      else
        {:ok, [{:send, sender, {:error, :counter_disabled}}]}
      end
    end

    on_message :reset, _payload, _config, env, sender do
      new_env = %{env | counter: 0, history: []}
      {:ok, [{:update_environment, new_env}, {:send, sender, {:ok, :reset}}]}
    end

    on_message :get_count, _payload, _config, env, sender do
      {:ok, [{:send, sender, {:count, env.counter}}]}
    end

    on_message :add, %{value: value}, config, env, sender do
      if env.enabled do
        new_counter = env.counter + value

        if config.mode == :limited and new_counter > env.max_count do
          {:ok, [{:send, sender, {:error, :max_count_reached}}]}
        else
          new_env = %{env | counter: new_counter}
          {:ok, [{:update_environment, new_env}, {:send, sender, {:ok, new_counter}}]}
        end
      else
        {:ok, [{:send, sender, {:error, :counter_disabled}}]}
      end
    end
  end
end
