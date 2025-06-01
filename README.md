# Engines in Elixir [![CI](https://github.com/anoma/engine/actions/workflows/ci.yml/badge.svg)](https://github.com/anoma/engine/actions/workflows/ci.yml)

A work-in-progress implementation of the Engine Model in Elixir.

An *engine* is an actor-like entity that enables type-safe message passing and
effectful actions through guarded actions. These actions can modify both the
engine's state and its environment.

Among other things, this library implements the Engine Model with a
[DSL](#dsl-for-engine-definition) and runtime system. The DSL lets you easily
define engines that follow the formal specification, including configuration,
state, message handling, and behaviours. The runtime system manages engine
lifecycles, message passing, monitoring, and introspection. See an initial [flow
diagram](operational-semantics-flow.md) of the operational semantics.

<!-- Details: cite the two papers here -->

<details>
<summary>Features & Requirements</summary>

### Core Features

- [x] Formal model-adherent implementation of the engine model
- [x] DSL for defining engines with configuration, environment, messages, and
  behaviour. Our first DSL implementation was implemented here:
  https://github.com/anoma/engine/commit/716344f81ab9c45f71b62c64d57a1ce60f32c939
- [x] Runtime system for managing engine lifecycles
- [x] Message passing between engines
- [x] Engine instance creation and management
- [x] Versioning support for all engine types

### System Capabilities

- [x] Asynchronous, non-blocking message passing system
- [x] Engine status and health monitoring
- [x] Engine type introspection
- [x] Runtime-swappable mailbox types with DSL support (requires a custom
  mailbox engines definition and some internal changes)
- [x] Engine type registration and lifecycle management
- [x] Message interface lookup and validation

#### Core Requirements

- [x] Engine type registration with system
- [x] Engine lifecycle management (start/stop)
- [x] Message passing and effect handling
- [x] Engine instance creation
- [x] Status and health monitoring
- [x] Location mobility for instances

#### Message Handling

- [x] System registry for message interfaces
- [x] Message validation against interfaces
- [x] Engine type documentation and introspection
- [x] Custom mailbox type definitions with DSL
- [x] Runtime mailbox type swapping

</details>

## Prerequisites & Installation

### Prerequisites

- Elixir 1.18.0 or higher
- Erlang/OTP 28 or higher

To check your Elixir version:

```shell
elixir --version
```

If you need to install or update Elixir, visit the [official installation
guide](https://elixir-lang.org/install.html).

### Installation

The package can be installed by adding `engine_system` to your list of
dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:engine_system, "~> 0.1.0"}
  ]
end
```

For experimentation and development:

1. Clone the repository:

```shell
git clone https://github.com/anoma/engine.git
cd engine
```

2. Install dependencies:

```shell
mix deps.get
```

3. Compile the project:

```shell
mix compile
```


# The Engine Model

A complete implementation of the actor model with explicit mailbox-as-actors
separation, based on the formal specifications described in the research paper.
This system implements the core innovation of promoting mailboxes to first-class
processing engines that receive messages but verify message writing using linked
processing engines.

<details>
<summary>Architecture Overview</summary>

The EngineSystem implements a clean separation between processing engines and
their mailboxes, following the formal model's operational semantics described in
the paper [CITE needed here].
Key architectural components include:

### Core Components

1. **Processing Engines** (`EngineSystem.Engine.Instance`)
   - GenStage consumers that process business logic
   - Maintain configuration, environment, and status state
   - Subscribe to their dedicated mailbox engines
   - Execute behavior rules and effects

2. **Mailbox Engines** (`EngineSystem.Mailbox.DefaultMailboxEngine`)
   - GenStage producers that act as first-class actors
   - Validate incoming messages against processing engine interfaces
   - Queue and filter messages based on processing engine state
   - Implement backpressure and demand-driven message delivery

3. **System Registry** (`EngineSystem.System.Registry`)
   - Central registry for engine specifications and running instances
   - Tracks address-to-PID mappings and metadata
   - Provides fresh ID generation and system-wide services

4. **DSL** (`EngineSystem.Engine.DSL`)
   - User-friendly Elixir Domain Specific Language
   - Compile-time generation of engine specifications
   - Automatic registration of engine types

## Key Features

### Mailbox-as-Actors Pattern

The core innovation is promoting mailboxes to first-class actors:

- **Mailboxes as first-class engines** that handle message reception and validation independently
- **Message validation** through contract checking against processing engine interfaces
- **Independent message filtering** and queueing policies per mailbox
- **Backpressure management** via GenStage demand-driven message flow


### OTP Supervision Tree

```
EngineSystem.Application
├── EngineSystem.Supervisor
    ├── EngineSystem.System.Registry (GenServer)
    ├── EngineSystem.Engine.DynamicSupervisor
    │   └── EngineSystem.Engine.Instance (GenStage Consumer)
    └── EngineSystem.Mailbox.DynamicSupervisor
        └── EngineSystem.Mailbox.DefaultMailboxEngine (GenStage Producer)
```

</details>

### DSL for Engine Definition

The DSL now features **compile-time validation**, a clean simplified syntax, and **unified import**. Engine definitions consist of:

- Declaring the engine mode (`:process` or `:mailbox`), by default `:process`
- Declaring the message interface and behaviour (mandatory)
- Declaring configuration and environment (optional but recommended)
- Message filters for selective processing (optional)

#### Simplified Import with `use EngineSystem`

The recommended approach is now to use a single import:

```elixir
use EngineSystem

defengine MyKVStore do
  version "2.0.0"
  mode :process  # New mandatory mode directive

  interface do
    message :get, key: :atom
    message :put, key: :atom, value: :any
    message :delete, key: :atom
    message :result, value: {:option, :any}
  end

  config do
    %{
      access_mode: :read_write,
      max_size: 1000,
      timeout: 30.5,
      retries_enabled: true
    }
  end

  env do
    %{
      store: %{},
      access_counts: %{},
      last_accessed: nil,
      active_connections: 0
    }
  end

  message_filter fn _msg, _config, _env -> true end

  behaviour do
    on_message :get, msg, _config, env, sender do
      key = msg[:key]
      value = Map.get(env.store, key, :not_found)
      {:ok, [{:send, sender, {:result, value}}]}
    end

    on_message :put, msg, _config, env, sender do
      {key, value} = {msg[:key], msg[:value]}
      new_store = Map.put(env.store, key, value)
      {:ok, [
        {:update_environment, %{env | store: new_store}},
        {:send, sender, :ack}
      ]}
    end

    on_message :delete, msg, _config, env, sender do
      key = msg[:key]
      new_store = Map.delete(env.store, key)
      {:ok, [
        {:update_environment, %{env | store: new_store}},
        {:send, sender, :ack}
      ]}
    end
  end
end

# You can now use all API functions directly:
{:ok, address} = spawn_engine(MyKVStore)
send_message(address, {:get, %{key: :my_key}})
```

#### Key DSL Features

- **Unified import**: Single `use EngineSystem` gives you DSL macros, utility functions, and API functions
- **Mode directive**: New mandatory `mode` directive to specify `:process` or `:mailbox` engines
- **Compile-time validation**: All handler functions are validated at compile time
- **Clean syntax**: No quote blocks or complex macros
- **Type safety**: Message interfaces enforce structure
- **Direct variable access**: Message payload, config, env, sender available in handlers
- **Effect system**: Return tuples with effects like `{:update_environment, new_env}`, `{:send, address, message}`
- **Stateless engines**: Environment is optional - engines can be stateless by default

#### Engine Modes

**Processing Engines** (`:process` mode):
```elixir
defengine MyProcessor do
  mode :process  # GenStage consumer for business logic
  # ... rest of definition
end
```

**Mailbox Engines** (`:mailbox` mode):
```elixir
defengine CustomMailbox do
  mode :mailbox  # GenStage producer for message queuing
  # ... rest of definition
end
```

#### Simple Examples

**Echo Engine:**
```elixir
use EngineSystem

defengine SimpleEcho do
  version "1.0.0"
  mode :process

  interface do
    message :echo, text: :string
  end

  behaviour do
    on_message :echo, msg, _config, _env, sender do
      {:ok, [{:send, sender, {:echo_reply, msg}}]}
    end
  end
end
```

**Stateless Calculator:**
```elixir
use EngineSystem

defengine StatelessCalculator do
  version "1.0.0"
  mode :process

  interface do
    message :add, a: :number, b: :number
    message :multiply, a: :number, b: :number
    message :result, value: :number
  end

  behaviour do
    on_message :add, msg, _config, _env, sender do
      {a, b} = {msg[:a], msg[:b]}
      {:ok, [{:send, sender, {:result, a + b}}]}
    end

    on_message :multiply, msg, _config, _env, sender do
      {a, b} = {msg[:a], msg[:b]}
      {:ok, [{:send, sender, {:result, a * b}}]}
    end
  end
end
```

**Counter with State:**
```elixir
use EngineSystem

defengine SimpleCounter do
  version "1.0.0"
  mode :process

  config do
    %{max_count: 100, step: 1}
  end

  env do
    %{count: 0, total_operations: 0}
  end

  interface do
    message(:increment)
    message(:decrement)
    message(:get_count)
    message(:reset)
    message(:count_response, value: :integer)
  end

  behaviour do
    on_message :increment, _msg, config, env, sender do
      new_count = min(env.count + config.step, config.max_count)
      new_env = %{env | count: new_count, total_operations: env.total_operations + 1}

      {:ok, [
        {:update_environment, new_env},
        {:send, sender, {:count_response, new_count}}
      ]}
    end

    on_message :get_count, _msg, _config, env, sender do
      {:ok, [{:send, sender, {:count_response, env.count}}]}
    end
  end
end
```

## Usage

### Starting the System

```elixir
# With unified import, start is directly available
use EngineSystem

# Start the EngineSystem application
{:ok, _} = start()
```

### Spawning Engine Instances

```elixir
# Spawn an engine with default configuration
{:ok, address} = spawn_engine(MyKVStore)

# Spawn with custom configuration
config = %{access_mode: :read_only}
{:ok, address} = spawn_engine(MyKVStore, config)

# Spawn with custom environment
env = %{store: %{initial_key: :initial_value}}
{:ok, address} = spawn_engine(MyKVStore, nil, env)

# Spawn with a name for easy lookup
{:ok, address} = spawn_engine(MyKVStore, nil, nil, :my_store)

# Spawn with custom mailbox engine
{:ok, address} = spawn_engine(MyKVStore, nil, nil, nil, CustomMailbox)
```

### Sending Messages

```elixir
# Send a message to an engine
:ok = send_message(address, {:get, %{key: :my_key}})

# Send with explicit sender
:ok = send_message(address, {:put, %{key: :new_key, value: :new_value}}, sender_address)
```

### System Management

```elixir
# List all running instances
instances = list_instances()

# Look up engine by address
{:ok, info} = lookup_instance(address)

# Look up engine by name
{:ok, address} = lookup_address_by_name(:my_store)

# Get system information
info = get_system_info()

# Terminate an engine
:ok = terminate_engine(address)

# Clean terminated engines
:ok = clean_terminated_engines()
```

### Interface Utilities

```elixir
# Check if engine supports a message
if has_message?(:MyKVStore, "2.0.0", :get) do
  IO.puts("Engine supports :get message")
end

# Get message fields for a specific message
{:ok, fields} = get_message_fields(:MyKVStore, "2.0.0", :put)

# Get all supported message tags
tags = get_message_tags(:MyKVStore, "2.0.0")

# Get message tags for a running instance
instance_tags = get_instance_message_tags(address)
```

## Implementation Details

### Formal Model Compliance

The implementation follows the operational semantics from the formal model:

- **s-EngineSpawn**: Implemented in `EngineSystem.System.Spawner`
- **m-Send, m-Enqueue, m-Dequeue**: Implemented in `EngineSystem.Mailbox.DefaultMailboxEngine`
- **s-Process**: Implemented in `EngineSystem.Engine.Instance`
- **Effect System**: Implemented in `EngineSystem.Engine.Effect`

### State Management

Each processing engine maintains three types of state:

1. **Configuration** (`EngineSystem.Engine.State.Configuration`)
   - Parent references and operational mode
   - Engine-specific configuration data

2. **Environment** (`EngineSystem.Engine.State.Environment`)
   - Local state and address book
   - Mutable data for business logic

3. **Status** (`EngineSystem.Engine.State.Status`)
   - Ready/busy/terminated states
   - Message filters for selective processing

### Message Flow

1. External message sent to engine address (or to a mailbox address directly).
2. System routes message to engine's mailbox in case of a processing engine's address.
3. Mailbox engines validate message against engine interface (contract checking)
4. Message queued if valid, filtered based on engine status (message filter).
5. Processing engine requests messages via GenStage demand
6. Mailbox delivers messages based on filter and demand via GenStage producer
7. Processing engine executes behaviour rules and effects

## Development Status

This implementation provides a robust foundation for the actor model with mailbox-as-actors separation and **compile-time validated DSL**. Key features implemented:

**Enhanced DSL and Unified Import**
- **Single import** via `use EngineSystem` for complete functionality
- **Mode directive** to specify processing vs. mailbox engines  
- **Compile-time function generation** for all message handlers
- **Type-safe message interfaces** with validation
- **Clean, quote-free syntax** for better IDE support
- **Automatic spec registration** with validation
- **Error detection at compile-time** rather than runtime

**Core Architecture**
- OTP supervision tree
- GenStage-based message flow
- System registry and services

**Mailbox-as-Actors**
- First-class mailbox engines (can be custom-defined with DSL)
- Message validation and filtering
- Demand-driven message delivery

**Processing Engines**
- GenStage consumers for business logic
- State management (configuration, environment, status)
- **Generated behavior functions** with compile-time validation

**System Management**
- Engine spawning and termination with custom mailbox support
- Address-based routing
- System information and statistics
- Interface introspection utilities

## Contributing

This implementation follows Elixir and OTP best practices.
When contributing:

1. Maintain the formal model compliance, read the paper to give you a better
   understanding of the model.
2. Follow the existing code organization
3. Add comprehensive tests for new features, they can live in separate files.
4. Update documentation for API changes, we use ExDoc and anoma/anoma coding
   standards.

