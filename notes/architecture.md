# Core Architecture

This document describes the architectural foundations of EngineSystem, based on the formal Engine Model that promotes mailboxes to first-class actors.

## Overview

The EngineSystem implements a clean separation between processing engines and their mailboxes, following the formal model's operational semantics. The key innovation is treating mailboxes as independent actors that validate and queue messages independently of their associated processing engines.

## Core Components

### 1. Processing Engines (`EngineSystem.Engine.Instance`)

Processing engines are GenStage consumers that handle business logic:

- **Purpose**: Execute message handlers and manage application state
- **Implementation**: GenStage consumer processes  
- **State Management**: Maintain configuration, environment, and status
- **Message Processing**: Subscribe to their dedicated mailbox engines
- **Effect Execution**: Process effects like sending messages and state updates

**Key Responsibilities:**
- Execute user-defined behavior rules
- Manage local state (environment and configuration)
- Process effects and side effects
- Handle backpressure via GenStage demand

### 2. Mailbox Engines (`EngineSystem.Mailbox.DefaultMailboxEngine`)

Mailbox engines are GenStage producers that act as first-class actors:

- **Purpose**: Receive, validate, queue, and deliver messages
- **Implementation**: GenStage producer processes
- **Independence**: Operate autonomously from processing engines
- **Validation**: Check incoming messages against processing engine interfaces
- **Filtering**: Apply message filters based on processing engine state

**Key Responsibilities:**
- Validate messages against interface contracts
- Queue messages using configurable policies (FIFO by default)
- Filter messages based on processing engine status
- Manage backpressure and demand-driven delivery
- Provide message delivery guarantees

### 3. System Registry (`EngineSystem.System.Registry`)

The central registry manages system-wide state and services:

- **Purpose**: Track engine specifications and running instances
- **Implementation**: GenServer with ETS backing store
- **Services**: Address resolution, ID generation, metadata management
- **Coordination**: Orchestrate engine spawning and termination

**Key Responsibilities:**
- Store engine specifications and metadata
- Maintain address-to-PID mappings
- Generate unique addresses and identifiers
- Provide system introspection capabilities
- Coordinate engine lifecycle events

### 4. DSL (`EngineSystem.Engine.DSL`)

The domain-specific language provides a clean interface for engine definition:

- **Purpose**: User-friendly engine definition syntax
- **Implementation**: Elixir macros with compile-time validation
- **Features**: Type checking, code generation, automatic registration
- **Integration**: Seamless integration with the runtime system

**Key Responsibilities:**
- Parse and validate engine definitions
- Generate engine specifications at compile time
- Provide syntax validation and error reporting
- Auto-register engine types with the system

## Architectural Patterns

### Mailbox-as-Actors Pattern

This is the core architectural innovation:

```
External Message → Mailbox Engine → Processing Engine
                      ↑
                   Validates &
                   Queues Messages
```

**Benefits:**
- **Independent validation**: Messages are checked before processing
- **Flexible queuing**: Different mailbox types can implement custom policies
- **Backpressure management**: Mailboxes handle demand-driven message flow
- **System resilience**: Mailbox failures don't directly affect processing engines

### State Separation

Each processing engine maintains three distinct types of state:

1. **Configuration**: Immutable settings and parameters
2. **Environment**: Mutable application state
3. **Status**: Engine operational status and message filters

This separation provides:
- Clear boundaries between different state types
- Predictable state management patterns
- Better debugging and introspection capabilities
- Support for hot code reloading

### Effect System

The effect system provides a functional approach to side effects:

```elixir
  @type t ::
        :noop
        | {:send, State.address(), any()}
        | {:update_environment, State.Environment.t()}
        | {:spawn, module(), any(), any()}
        | {:mfilter, function()}
        | :terminate
        | {:chain, [t()]}
```

## OTP Supervision Tree

```
EngineSystem.Application
├── EngineSystem.Supervisor
    ├── EngineSystem.System.Registry (GenServer)
    ├── EngineSystem.Engine.DynamicSupervisor
    │   └── EngineSystem.Engine.Instance (GenStage Consumer)
    └── EngineSystem.Mailbox.DynamicSupervisor
        └── EngineSystem.Mailbox.DefaultMailboxEngine (GenStage Producer)
```

**Design Principles:**
- **Isolation**: Engines and mailboxes are supervised separately
- **Fault tolerance**: Failures are contained and handled gracefully
- **Dynamic management**: Engines can be spawned and terminated at runtime
- **Resource management**: Supervisors handle cleanup and resource allocation

## Module Organization

```
lib/
├── engine_system.ex                    # Main API module
├── engine_system/
│   ├── application.ex                  # OTP Application
│   ├── supervisor.ex                   # Main supervisor
│   ├── engine/
│   │   ├── instance.ex                 # Processing engine implementation
│   │   ├── dsl.ex                      # DSL macros and validation
│   │   ├── effect.ex                   # Effect execution
│   │   ├── spec.ex                     # Engine specifications
│   │   └── state/
│   │       ├── configuration.ex        # Configuration state
│   │       ├── environment.ex          # Environment state
│   │       └── status.ex               # Status state
│   ├── mailbox/
│   │   ├── default_mailbox.ex          # Default mailbox implementation
│   │   └── behaviour.ex                # Mailbox behavior definition
│   └── system/
│       ├── registry.ex                 # System registry
│       ├── spawner.ex                  # Engine spawning logic
│       └── address.ex                  # Address utilities
```

## Design Principles

### 1. Formal Model Compliance

The implementation strictly follows the operational semantics defined in the formal model:

- **s-EngineSpawn**: Engine creation process
- **m-Send/m-Enqueue/m-Dequeue**: Message handling operations  
- **s-Process**: Core processing rule with state transitions

### 2. Type Safety

Compile-time and runtime validation ensure type safety:

- Message interfaces define contracts
- DSL provides compile-time validation
- Runtime type checking prevents invalid messages

### 3. Fault Tolerance

Built on OTP principles for robust systems:

- Supervisor trees provide fault isolation
- Let-it-crash philosophy with graceful recovery
- Monitoring and health checking

### 4. Performance

Optimized for high-throughput message processing:

- GenStage provides backpressure management
- Efficient message queuing and routing
- Minimal overhead in the critical path

### 5. Extensibility

Designed for customization and extension:

- Pluggable mailbox implementations
- Configurable message policies
- Extensible effect system

## Inter-Component Communication

### Engine-to-Engine Communication

```
Engine A → Mailbox A → System Router → Mailbox B → Engine B
```

1. Engine A sends message via effect
2. Message routes through system registry
3. Target mailbox validates and queues message
4. Target engine processes message when ready

### System-to-Engine Communication

```
External API → System Registry → Mailbox → Engine
```

1. External system calls API function
2. Registry resolves target address
3. Message delivered to appropriate mailbox
4. Engine processes message asynchronously

### Monitoring and Introspection

```
Registry ← Monitor ← Engines/Mailboxes
    ↓
System Info API
```

1. Components register with system monitoring
2. Health and status information collected
3. Exposed through introspection APIs
4. Used for debugging and operations

This architecture provides a solid foundation for building distributed, fault-tolerant systems with strong message contracts and predictable behavior. 