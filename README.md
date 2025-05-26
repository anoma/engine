# Engines in Elixir [![CI](https://github.com/anoma/engine/actions/workflows/ci.yml/badge.svg)](https://github.com/anoma/engine/actions/workflows/ci.yml)

A work-in-progress implementation of the Engine Model in Elixir.

An *engine* is an actor-like entity that enables type-safe message passing and
effectful actions through guarded actions. These actions can modify both the
engine's state and its environment.

Among other things, this library implements the Engine Model with a
[DSL](#dsl-for-engine-definition) and runtime system. The DSL lets you easily
define engines that follow the formal specification, including configuration,
state, message handling, and behaviours. The runtime system manages engine
lifecycles, message passing, monitoring, and introspection. See an initial [flow diagram](operational-semantics-flow.md) of the operational semantics.

<!-- Details: cite the two papers here -->

<details>
<summary>Features & Requirements</summary>

### Core Features

- [x] Formal model-adherent implementation of the engine model
- [x] DSL for defining engines with configuration, environment, messages, and
  behavior
- [x] Runtime system for managing engine lifecycles
- [x] Message passing between engines
- [x] Engine instance creation and management
- [x] Versioning support for all engine types

### System Capabilities

- [x] Asynchronous, non-blocking message passing system
- [x] Engine status and health monitoring
- [x] Engine type introspection
- [ ] Runtime-swappable mailbox types
- [x] Engine type registration and lifecycle management
- [x] Message interface lookup and validation

#### Core Requirements

- [x] Engine type registration with system
- [x] Engine lifecycle management (start/stop)
- [ ] Message passing and effect handling
- [x] Engine instance creation
- [x] Status and health monitoring
- [ ] Location mobility for instances

#### Message Handling

- [x] System registry for message interfaces
- [x] Message validation against interfaces
- [x] Engine type documentation and introspection
- [x] Custom mailbox type definitions
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

```elixir
import EngineSystem.Engine.DSL

defengine MyKVStore do
  version "1.0.0"

  interface do
    message :get, key: :atom
    message :put, key: :atom, value: :any
    message :delete, key: :atom
    message :result, value: {:option, :any}
  end

  config kv_config: %{access_mode: :read_write, max_size: 1000} do
    field :access_mode, default: :read_write, type: :atom
    field :max_size, default: 1000, type: :integer
  end

  environment kv_env: %{store: %{}, access_counts: %{}} do
    field :store, default: %{}, type: :map
    field :access_counts, default: %{}, type: :map
  end

  # This informs the mailbox engine to deliver messages that pass this filter
  # and discard messages that don't pass it (need to review this in the paper .
  message_filter fn _msg, _config, _env -> true end

  behaviour do
    on_message :get do
      # Business logic here... you have access to the engine's configuration, environment, and state
      {:ok, :noop}
    end
    ...
  end
end
```

## Usage

### Starting the System

```elixir
# Start the EngineSystem application
{:ok, _} = EngineSystem.start()
```

### Spawning Engine Instances

```elixir
# Spawn an engine with default configuration
{:ok, address} = EngineSystem.spawn_engine(MyKVStore)

# Spawn with custom configuration
config = %{access_mode: :read_only}
{:ok, address} = EngineSystem.spawn_engine(MyKVStore, config)

# Spawn with a name for easy lookup
{:ok, address} = EngineSystem.spawn_engine(MyKVStore, nil, nil, :my_store)
```

### Sending Messages

```elixir
# Send a message to an engine
:ok = EngineSystem.send_message(address, {:get, :my_key})

# Send with explicit sender
:ok = EngineSystem.send_message(address, {:put, :key, :value}, sender_address)
```

### System Management

```elixir
# List all running instances
instances = EngineSystem.list_instances()

# Look up engine by address
{:ok, info} = EngineSystem.lookup_instance(address)

# Look up engine by name
{:ok, address} = EngineSystem.lookup_address_by_name(:my_store)

# Get system information
info = EngineSystem.get_system_info()

# Terminate an engine
:ok = EngineSystem.terminate_engine(address)
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

## File Structure

```
lib/
├── engine_system.ex                    # Main facade API
├── engine_system/
│   ├── application.ex                  # OTP Application
│   ├── supervisor.ex                   # Main supervisor
│   ├── engine/
│   │   ├── dsl.ex                     # DSL macros
│   │   ├── spec.ex                    # Engine specifications
│   │   ├── state.ex                   # State structs
│   │   ├── instance.ex                # Processing engine GenStage
│   │   ├── behaviour.ex               # Message processing logic
│   │   └── effect.ex                  # Effect execution
│   ├── mailbox/
│   │   ├── message.ex                 # Message struct
│   │   └── default_mailbox_engine.ex  # Mailbox GenStage
│   └── system/
│       ├── registry.ex                # System registry
│       ├── services.ex                # System services
│       └── spawner.ex                 # Engine spawning logic
└── examples/
    └── kv_store_engine.ex             # Example engine
```

## Testing

Run the test suite:

```bash
mix test
```

The tests demonstrate:
- System startup/shutdown
- Engine specification registration and lookup
- Engine instance spawning and management
- System information and statistics
- Engine termination and cleanup

## Development Status

This implementation provides a solid foundation for the actor model with mailbox-as-actors separation. Key features implemented:

✅ **Core Architecture**
- OTP supervision tree
- GenStage-based message flow
- System registry and services

✅ **DSL and Specifications**
- Compile-time engine specification generation
- Interface, configuration, and environment definitions
- Automatic spec registration

✅ **Mailbox-as-Actors**
- First-class mailbox engines
- Message validation and filtering
- Demand-driven message delivery

✅ **Processing Engines**
- GenStage consumers for business logic
- State management (configuration, environment, status)
- Behavior rule execution framework

✅ **System Management**
- Engine spawning and termination
- Address-based routing
- System information and statistics

### Future Enhancements

- **Message Routing**: Enhanced routing for distributed systems
- **Persistence**: State persistence and recovery mechanisms
- **Monitoring**: Advanced monitoring and observability
- **Performance**: Optimizations for high-throughput scenarios
- **Security**: Authentication and authorization mechanisms

## Contributing

This implementation follows Elixir and OTP best practices. When contributing:

1. Maintain the formal model compliance
2. Follow the existing code organization
3. Add comprehensive tests for new features
4. Update documentation for API changes

## License

[Add your license information here]

