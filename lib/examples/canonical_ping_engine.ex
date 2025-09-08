use EngineSystem

defengine Examples.CanonicalPingEngine, generate_diagrams: true do
  @moduledoc """
  I am a canonical Ping engine that sends pong responses.

  This is a minimal, clean implementation for diagram generation testing.
  I only handle :ping messages and respond with :pong.
  """

  version("1.0.0")
  mode(:process)

  env do
    %{
      ping_count: 0
    }
  end

  config do
    %{
      auto_respond: true
    }
  end

  interface do
    message(:ping)
  end

  behaviour do
    on_message :ping, _payload, config, env, sender do
      new_env = %{env | ping_count: env.ping_count + 1}

      if config.auto_respond do
        {:ok,
         [
           {:update_environment, new_env},
           {:send, sender, :pong}
         ]}
      else
        {:ok,
         [
           {:update_environment, new_env}
         ]}
      end
    end
  end
end
