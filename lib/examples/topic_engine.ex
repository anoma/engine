use EngineSystem

defengine Examples.TopicEngine do
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

### `config_param_1` ([Type], default: [value])
[Description of what this parameter controls and how it affects behavior]

### `config_param_2` ([Type], default: [value])
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
**Response Format**: `{:response_type, value}` or `{:error, reason}`
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
EngineSystem.API.send_message(engine_addr, {:message_type, %{param: "value"}})
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
- **[Use Case 3]**: [Additional scenario where this engine provides value]

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
    message(:new)
    message(:sub)
    message(:unsub)
    message(:pub, msg: :any)
    message(:ack)
  end

  env do
    %{subs: %{}}
  end

  behaviour do
    on_message :new, %{}, _config, env, sender do
      if map_size(env.subs) == 0 do
        subs = Map.put(%{}, sender, true);
        env = %{env | subs: subs}
        {:ok, [{:update_environment, env}, {:send, sender, :ack}]}
      else
        {:error, {:already_exists}}
      end
    end

    on_message :sub, %{}, _config, env, sender do
      subs = Map.put(env.subs, sender, false)
      env = %{env | subs: subs}
      {:ok, [{:update_environment, env}, {:send, sender, :ack}]}
    end

    on_message :unsub, %{}, _config, env, sender do
      subs = Map.delete(env.subs, sender)
      env = %{env | subs: subs}
      {:ok, [{:update_environment, env}, {:send, sender, :ack}]}
    end

    on_message :pub, %{msg: msg}, _config, env, sender do
      if Map.get(env.subs, sender) == true do
        fx = Enum.map(env.subs, fn ({id, _is_publisher}) -> {:send, id, msg} end)
        {:ok, fx}
      else
        {:error, {:permission_denied}}
      end
    end
  end
end
