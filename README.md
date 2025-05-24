# Engines in Elixir
A formal model implementation of engines in Elixir (work in progress).

An engine is an actor-like entity that enables type-safe message passing and
effectful actions through guarded actions. These actions can modify both the
engine's state and its environment.

This library implements the Engine Model with a metaprogramming DSL and runtime
system. The DSL lets you define engines that follow the formal specification,
including configuration, state, message handling, and behaviours. The runtime
system manages engine lifecycles, message passing, monitoring, and
introspection.

<!-- Details: cite the two papers here -->

<details>
<summary>Features & Requirements</summary>

### Core Features

- [ ] Formal model-adherent implementation of the engine model
- [ ] DSL for defining engines with configuration, environment, messages, and
  behavior
- [ ] Runtime system for managing engine lifecycles
- [ ] Message passing between engines
- [ ] Engine instance creation and management
- [ ] Versioning support for all engine types

### System Capabilities

- [ ] Asynchronous, non-blocking message passing system
- [ ] Engine status and health monitoring
- [ ] Engine type introspection
- [ ] Runtime-swappable mailbox types
- [ ] Engine type registration and lifecycle management
- [ ] Message interface lookup and validation

#### Core Requirements

- [ ] Engine type registration with system
- [ ] Engine lifecycle management (start/stop)
- [ ] Message passing and effect handling
- [ ] Engine instance creation
- [ ] Status and health monitoring
- [ ] Location mobility for instances

#### Message Handling

- [ ] System registry for message interfaces
- [ ] Message validation against interfaces
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

If you need to install or update Elixir, visit the [official installation guide](https://elixir-lang.org/install.html).

### Installation

The package can be installed by adding `engine_system` to your list of dependencies in `mix.exs`:

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

