use EngineSystem

defengine Examples.CanonicalPongEngine, generate_diagrams: true do
  @moduledoc """
  I am a canonical Pong engine that receives pong messages.
  
  This is a minimal, clean implementation for diagram generation testing.
  I only handle :pong messages and count them.
  """

  version("1.0.0")
  mode(:process)

  env do
    %{
      pong_count: 0,
      last_sender: nil
    }
  end

  config do
    %{}
  end

  interface do
    message(:pong)
  end

  behaviour do
    on_message :pong, _payload, _config, env, sender do
      new_env = %{env | 
        pong_count: env.pong_count + 1,
        last_sender: sender
      }
      
      {:ok, [
        {:update_environment, new_env}
      ]}
    end
  end
end