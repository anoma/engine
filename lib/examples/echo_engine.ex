use EngineSystem

defengine Examples.EchoEngine do
  @moduledoc """
  ## Who I Am

  I am a simple echo engine that serves as the foundational example of message
  handling and response patterns within the EngineSystem architecture. I'm your
  first step into understanding how engines communicate and interact.

  ## My Purpose

  I serve as a fundamental demonstration engine with several key roles:
  - **Educational Foundation**: I teach the core concepts of engine message passing
  - **Testing Utility**: I provide reliable echo responses for testing other engines
  - **Communication Baseline**: I demonstrate the simplest form of request-response patterns
  - **Integration Testing**: I verify that basic message routing works correctly

  I'm particularly valuable for developers learning the EngineSystem or for testing
  scenarios where you need predictable, immediate responses.

  ## Public API (Message Interface)

  I accept three types of messages and provide corresponding responses:

  ### `:echo` - Content Echo Service
  **Request Format**: `{:echo, %{content: any_value}}`
  **Response Format**: `{:echo, content}`
  **Purpose**: Echo back any content sent to me

  ### `:ping` - Connectivity Testing
  **Request Format**: `:ping`
  **Response Format**: `:pong`
  **Purpose**: Simple connectivity and responsiveness testing

  ### `:pong` - Protocol Completion
  **Request Format**: `:pong`
  **Response Format**: None (I acknowledge receipt)
  **Purpose**: Complete ping-pong protocol cycles

  ## Message Handling

  Here's exactly what happens when I receive each message type:

  ### When I Receive `:echo` Messages

  1. **Message Parsing**: I extract the `content` field from the message payload
  2. **Content Processing**: I handle both structured (`%{content: value}`) and direct content
  3. **Response Generation**: I wrap the content in an `{:echo, content}` tuple
  4. **Sender Response**: I send the echoed content back to the original sender
  5. **Effect**: The sender receives their content echoed back exactly as sent

  ```elixir
  # Input:  {:echo, %{content: "Hello World!"}}
  # Output: {:echo, "Hello World!"} sent back to sender
  ```

  ### When I Receive `:ping` Messages

  1. **Protocol Recognition**: I recognize this as a connectivity test
  2. **Immediate Response**: I generate a `:pong` response without processing payload
  3. **Sender Notification**: I send `:pong` back to the original sender
  4. **Effect**: The sender knows I'm alive and responsive

  ```elixir
  # Input:  :ping
  # Output: :pong sent back to sender
  ```

  ### When I Receive `:pong` Messages

  1. **Protocol Acknowledgment**: I recognize this as a ping-pong completion
  2. **Silent Handling**: I accept the pong without generating responses
  3. **State Preservation**: I maintain my state unchanged
  4. **Effect**: The ping-pong protocol cycle completes successfully

  ```elixir
  # Input:  :pong
  # Output: No response (protocol completion)
  ```

  ## Usage Examples

  ### Basic Echo Testing
  ```elixir
  # Spawn me
  {:ok, echo_addr} = EngineSystem.API.spawn_engine(Examples.EchoEngine)

  # Send me content to echo
  EngineSystem.API.send_message(echo_addr, {:echo, %{content: "Hello World!"}})
  # I respond with: {:echo, "Hello World!"}

  # Test with different content types
  EngineSystem.API.send_message(echo_addr, {:echo, %{content: 42}})
  # I respond with: {:echo, 42}
  ```

  ### Connectivity Testing
  ```elixir
  # Test if I'm responsive
  EngineSystem.API.send_message(echo_addr, :ping)
  # I respond with: :pong

  # Complete the protocol
  EngineSystem.API.send_message(echo_addr, :pong)
  # I acknowledge silently
  ```

  ## Integration Scenarios

  I'm particularly useful in these scenarios:
  - **Engine Development**: Testing new engines by sending them echo requests
  - **Message Routing**: Verifying that messages reach their intended destinations
  - **System Health**: Quick connectivity checks using ping-pong protocol
  - **Load Testing**: Generating predictable responses for performance testing
  - **Learning**: Understanding basic engine communication patterns

  ## Design Philosophy

  I embody the principle of simplicity in engine design:
  - **Minimal State**: I operate without maintaining any persistent state
  - **Immediate Response**: I respond immediately without complex processing
  - **Reliable Patterns**: I implement predictable, testable communication patterns
  - **Clear Interface**: My message interface is intuitive and self-documenting

  I serve as the perfect starting point for understanding how engines work and
  provide a reliable foundation for testing more complex engine interactions.
  """

  version("1.0.0")
  # This is a processing engine
  mode(:process)

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
