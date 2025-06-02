use EngineSystem

defengine Examples.EnhancedEchoEngine do
  @moduledoc "Enhanced echo engine that can interact with GenServers and show visible effects."

  version("1.0.0")
  mode(:process)

  env do
    %{
      echo_count: 0,
      genserver_notifications: 0
    }
  end

  interface do
    message(:echo, [:content])
    message(:ping)
    message(:pong)
    message(:notify_genserver, [:message])
  end

  behaviour do
    # Handle echo messages - echo back to sender
    on_message :echo, msg_payload, _config, env, sender do
      content = msg_payload[:content] || msg_payload
      new_env = Map.put(env, :echo_count, env.echo_count + 1)

      IO.puts("📢 EchoEngine: Echoing message ##{new_env.echo_count}: #{inspect(content)}")

      # Handle echo response based on sender type
      case sender do
        {:genserver, pid} when is_pid(pid) ->
          # Send echo response directly to GenServer
          send(pid, {:engine_message, self(), {:echo_response, content}})
          IO.puts("📢 EchoEngine: Sent echo response to GenServer #{inspect(pid)}")
          {:ok, [{:update_environment, new_env}]}

        engine_address ->
          # Send echo back to engine using standard effect
          {:ok,
           [
             {:update_environment, new_env},
             {:send, engine_address, {:echo_response, content}}
           ]}
      end
    end

    # Handle ping messages
    on_message :ping, _msg_payload, _config, env, sender do
      new_env = Map.put(env, :echo_count, env.echo_count + 1)
      IO.puts("📢 EchoEngine: Received ping, sending pong back")

      {:ok,
       [
         {:update_environment, new_env},
         {:send, sender, :pong}
       ]}
    end

    # Handle pong messages
    on_message :pong, _msg_payload, _config, _env, sender do
      IO.puts("🤔 EnhancedEchoEngine: Received unexpected pong from #{inspect(sender)}")
      {:ok, []}
    end

    # Handle GenServer notification requests
    on_message :notify_genserver, %{message: message}, _config, env, sender do
      new_env = Map.put(env, :genserver_notifications, env.genserver_notifications + 1)

      IO.puts(
        "📢 EchoEngine: Sending notification ##{new_env.genserver_notifications} to GenServer"
      )

      # For GenServer communication, we need to extract the PID from sender address
      # and send a regular Elixir message
      case sender do
        {:genserver, pid} when is_pid(pid) ->
          # Send a message directly to the GenServer process
          send(pid, {:engine_message, self(), {:engine_notification, message}})
          IO.puts("📢 EchoEngine: Sent message to GenServer #{inspect(pid)}")

        other ->
          IO.puts("📢 EchoEngine: Invalid GenServer sender: #{inspect(other)}")
      end

      {:ok, [{:update_environment, new_env}]}
    end
  end
end
