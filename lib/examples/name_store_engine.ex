use EngineSystem

defmodule Examples.NameStoreEngine.Record do
  alias ElixirLS.LanguageServer.Providers.Completion.Reducers.Bitstring
  use TypedStruct

  typedstruct do
    @typedoc """
    I define the structure for a mailbox message.

    ### Fields

    - `:sender` - The sender's address (optional). Enforced: false.
    - `:target` - The target engine's address. Enforced: true.
    - `:content` - The message payload. Enforced: true.
    """
    field(:type, :atom, enforce: true)
    field(:id, Integer, enforce: true)
    field(:content, any(), enforce: true)
    field(:version, Integer, enforce: true)
    field(:created, DateTime, enforce: true)
    field(:sig, Bitstring, enforce: true)
  end

  def new(type, id, content, version, created, sig) do
    %__MODULE__{
      type: type,
      id: id,
      content: content,
      version: version,
      created: created,
      sig: sig
    }
  end
end

defmodule Examples.NameStoreEngine.RecordContent do
  # TODO
end

defengine Examples.NameStoreEngine do
  @moduledoc """
  ## Who I Am

  I am [brief identity statement in first person]. I [describe what you do] and serve as [your role in the system].

  ## My Purpose

  I serve [multiple/specific] roles within the EngineSystem ecosystem:
  - **[Primary Role]**: [Description of main functionality]
  - **[Secondary Role]**: [Description of secondary functionality]
  - **[Educational Role]**: [What concepts I demonstrate/teach]
  - **[Integration Role]**: [How I work with other components]

  I'm particularly valuable for [specific use cases where this engine shines].

  ## My Configuration (if applicable)

  I use [configuration approach - e.g., "simplified configuration syntax with automatic type inference"]:

  ### `config_param_1` ([Type], default: [rec])
  [Description of what this parameter controls and how it affects behavior]

  ### `config_param_2` ([Type], default: [rec])
  [Description of what this parameter controls and how it affects behavior]

  ## My Internal State (if applicable for stateful engines)

  I maintain [number] primary state components that persist across all operations:

  ### `state_component_1` - [Purpose]
  [Description of what this state component contains and represents]

  ### `state_component_2` - [Purpose]
  [Description of what this state component contains and represents]

  ## Public API (Message Interface)

  I [accept/handle] [number] types of messages and provide corresponding responses:

  ### `:message_type_1` - [Brief Description]
  **Request Format**: `{:message_type_1, %{param: type}}`
  **Response Format**: `{:response_type, rec}` or `{:error, reason}`
  **Purpose**: [What this message accomplishes]

  ### `:message_type_2` - [Brief Description]
  **Request Format**: `:message_type_2`
  **Response Format**: `response_value`
  **Purpose**: [What this message accomplishes]

  ## Message Handling

  Here's exactly what happens when I receive each message type:

  ### When I Receive `:message_type_1` Messages

  1. **[Step 1]**: [What happens first]
  2. **[Step 2]**: [What happens second]
  3. **[Step 3]**: [What happens third]
  4. **[Step 4]**: [What happens fourth]
  5. **[Step 5]**: [Final step and response]

  ```elixir
  # Input:  {:message_type_1, %{param: "example"}}
  # Process: [description of processing]
  # State:  [description of state changes, if any]
  # Output: {:response, "result"} sent back to sender
  ```

  ### When I Receive `:message_type_2` Messages

  1. **[Step 1]**: [Describe processing steps]
  2. **[Step 2]**: [Continue with processing flow]
  3. **[etc.]**: [Continue as needed]

  ```elixir
  # Input:  :message_type_2
  # Process: [description]
  # Output: response_value sent back to sender
  ```

  ## Error Conditions (if applicable)

  I generate specific errors for different failure scenarios:

  ### `:error_type_1`
  Returned when [condition that triggers this error].
  This [protects against/prevents] [specific problem].

  ### `:error_type_2`
  Returned when [condition that triggers this error].
  This [protects against/prevents] [specific problem].

  ## Usage Examples

  ### Basic Operations
  ```elixir
  # Spawn me
  {:ok, engine_addr} = EngineSystem.API.spawn_engine(Examples.YourEngine)

  # Basic usage
  EngineSystem.API.send_message(engine_addr, {:message_type, %{param: "rec"}})
  # I respond with: {:response, "result"}
  ```

  ### Advanced Usage (if applicable)
  ```elixir
  # Advanced scenarios
  # [Show more complex usage patterns]
  ```

  ### Error Handling Examples (if applicable)
  ```elixir
  # Test error conditions
  # [Show how errors are triggered and handled]
  ```

  ## Integration Scenarios

  I'm particularly useful in these scenarios:
  - **[Use Case 1]**: [Description of when and how to use this engine]
  - **[Use Case 2]**: [Another practical application]
  - **[Use Case 3]**: [Additional scenario where this engine provides rec]

  ## [Additional Sections as Needed]

  ### Extensibility (for foundational engines)
  [How this engine can be extended or built upon]

  ### State Management Patterns (for stateful engines)
  [Key patterns demonstrated in state handling]

  ### Configuration Patterns (for configurable engines)
  [Important configuration concepts demonstrated]

  ## Design Philosophy

  I embody [key design principle] in engine design:
  - **[Principle 1]**: [How this engine demonstrates this principle]
  - **[Principle 2]**: [Another key design aspect]
  - **[Principle 3]**: [Additional design consideration]

  I serve as both a practical utility for [primary use case] and an
  educational example of [key concepts] within the EngineSystem.
  """

  version("1.0.0")
  # This is a processing engine
  mode(:process)

  interface do
    message(:put, zone: :atom, label: :atom, type: :atom, rec: Examples.NameStoreEngine.Record)
    message(:get, zone: :atom, label: :atom, type: :atom)
    message(:delete, zone: :atom, label: :atom, type: :atom, id: Integer)
    message(:result, rec: :any)
    message(:ack)
  end

  env do
    %{
      store: %{}
    }
  end

  behaviour do
    on_message :put,
               %{zone: zone, label: label, record: rec},
               _config,
               env,
               sender do
      key = Enum.join([zone, label, rec.type, rec.id], "|")
      store = Map.put(env.store, key, rec)
      env = %{env | store: store}

      {
        :ok,
        [
          {:update_environment, env},
          {:send, sender, :ack}
        ]
      }
    end

    on_message :get, %{zone: zone, label: label, type: type}, _config, env, sender do
      prefix = Enum.join([zone, label, type], "|")
      result = Map.filter(env.store, fn k, _v -> String.starts_with?(k, prefix) end)

      {
        :ok,
        [
          {:send, sender, {:result, result}}
        ]
      }
    end

    on_message :delete, %{zone: zone, label: label, type: type, id: id}, _config, env, sender do
      key = Enum.join([zone, label, type, id], "|")
      store = Map.delete(env.store, key)
      env = %{env | store: store}

      {
        :ok,
        [
          {:update_environment, env},
          {:send, sender, :ack}
        ]
      }
    end
  end
end
