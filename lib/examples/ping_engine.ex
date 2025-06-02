use EngineSystem

defengine Examples.PingEngine do
  @moduledoc "Ping engine that sends ping messages to a configured target."

  version("1.0.0")
  mode(:process)

  env do
    %{
      ping_count: 0,
      target: nil
    }
  end

  interface do
    message(:ping)
    message(:pong)
    message(:set_target, [:target_address])
    message(:send_ping)
  end

  behaviour do
    # Handle configuration update for target
    on_message :set_target, %{target_address: target}, _config, env, _sender do
      new_env = Map.put(env, :target, target)
      IO.puts("🎯 PingEngine: Target set to #{inspect(target)}")
      {:ok, [{:update_environment, new_env}]}
    end

    # Handle send_ping command
    on_message :send_ping, _msg_payload, _config, env, _sender do
      if env.target do
        new_env = Map.put(env, :ping_count, env.ping_count + 1)
        IO.puts("🏓 PingEngine: Sending ping ##{new_env.ping_count} to #{inspect(env.target)}")

        {:ok,
         [
           {:update_environment, new_env},
           {:send, env.target, :ping}
         ]}
      else
        IO.puts("❌ PingEngine: No target configured")
        {:ok, []}
      end
    end

    # Handle incoming ping (reply with pong)
    on_message :ping, _msg_payload, _config, env, sender do
      new_env = Map.put(env, :ping_count, env.ping_count + 1)
      IO.puts("🏓 PingEngine: Received ping from #{inspect(sender)}, sending pong back")

      {:ok,
       [
         {:update_environment, new_env},
         {:send, sender, :pong}
       ]}
    end

    # Handle incoming pong
    on_message :pong, _msg_payload, _config, _env, sender do
      IO.puts("🎉 PingEngine: Received pong from #{inspect(sender)}!")
      {:ok, []}
    end
  end
end
