use EngineSystem

defengine Examples.PongEngine do
  @moduledoc "Pong engine that responds to ping messages with pong."

  version("1.0.0")
  mode(:process)

  env do
    %{pong_count: 0}
  end

  interface do
    message(:ping)
    message(:pong)
  end

  behaviour do
    # Handle incoming ping (reply with pong)
    on_message :ping, _msg_payload, _config, env, sender do
      new_env = Map.put(env, :pong_count, env.pong_count + 1)

      IO.puts(
        "🏓 PongEngine: Received ping from #{inspect(sender)}, sending pong ##{new_env.pong_count}"
      )

      {:ok,
       [
         {:update_environment, new_env},
         {:send, sender, :pong}
       ]}
    end

    # Handle incoming pong (shouldn't normally happen but handle gracefully)
    on_message :pong, _msg_payload, _config, _env, sender do
      IO.puts("🤔 PongEngine: Received unexpected pong from #{inspect(sender)}")
      {:ok, []}
    end
  end
end
