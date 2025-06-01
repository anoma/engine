use EngineSystem

defengine Examples.EchoEngine do
  @moduledoc "Simple echo engine that echoes back any message."

  version("1.0.0")
  mode :process  # This is a processing engine

  interface do
    message(:echo, content: :any)
    message(:ping)
    message(:pong)
  end

  behaviour do
    on_message :echo, msg_payload, _config, _env, sender do
      content = msg_payload[:content] || msg_payload
      {:ok, [{:send, sender, {:echo, content}}]}
    end

    on_message :ping, _msg_payload, _config, _env, sender do
      {:ok, [{:send, sender, :pong}]}
    end
  end
end
