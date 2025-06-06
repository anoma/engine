# Engine Documentation Template

Use this template as a guide when documenting engines in the `@moduledoc` section. Replace the bracketed placeholders with engine-specific content.

```elixir
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

## Documentation Guidelines

### Writing Style

- **First Person**: Always write from the engine's perspective ("I am...", "I do...", "I serve...")
- **Active Voice**: Use active voice for clarity ("I process messages" not "Messages are processed")
- **Present Tense**: Describe current behaviour ("I respond with" not "I will respond with")

### Content Requirements

#### Essential Sections (All Engines)

- **Who I Am**: Brief, engaging identity statement
- **My Purpose**: Clear value proposition with bullet points
- **Public API**: Complete message interface specification
- **Message Handling**: Step-by-step processing workflows with examples
- **Usage Examples**: Practical code samples
- **Integration Scenarios**: Real-world applications

#### Conditional Sections

- **My Configuration**: Include if engine accepts configuration parameters
- **My Internal State**: Include if engine maintains persistent state
- **Error Conditions**: Include if engine can generate specific errors
- **Design Philosophy**: Include for engines that demonstrate important patterns

### Code Examples

- Always use `EngineSystem.API.spawn_engine()` and `EngineSystem.API.send_message()`
- Include both input and expected output
- Show realistic parameter values
- Format consistently with proper syntax highlighting

### Message Handling Details

This is the **most important section**. For each message type, include:
1. **Processing Steps**: Numbered list of exactly what happens
2. **State Changes**: How the engine's state is modified (if applicable)
3. **Side Effects**: Any effects beyond state changes
4. **Response Generation**: What response is sent back
5. **Code Example**: Input/Process/Output example in comments

### Quality Checklist

- [ ] First-person narrative throughout
- [ ] Clear purpose statement with practical value
- [ ] Complete message interface specification
- [ ] Detailed message handling workflows
- [ ] Practical usage examples with real code
- [ ] Integration scenarios for real-world applications
- [ ] Consistent formatting and style
- [ ] All examples are tested and working 