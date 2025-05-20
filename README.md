# Engines in Elixir
A formal model-adherent implementation of distributed engines in Elixir.

This library implements the Engine Model, providing a metaprogramming-based DSL for defining engines and a runtime system for executing them. The DSL allows you to define engines that are fully compatible with the formal Engine Model specification, with built-in support for configuration, environment state, message handling, and behavior definition. The runtime system manages engine lifecycles, handles message passing between engines, and provides monitoring and introspection capabilities.

<details>
<summary>Features & Requirements</summary>

### Core Features
- [ ] Formal model-adherent implementation of the engine model
- [ ] DSL for defining engines with configuration, environment, messages, and behavior
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

- Elixir 1.14.0 or higher
- Erlang/OTP 24 or higher

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

## Quick Start

Let's quickly get a key-value store engine running:

```shell
# Start the Elixir interactive shell
iex -S mix

# In the IEx session, run the KVStore example
Examples.KVStoreDemo.run()
```

You should see output showing the engine starting, sending messages, and processing requests.

## Core Concepts

The EngineSystem implements the Engine Model, which consists of:

- **Engines**: Computational units that operate on local state (environments) and communicate via messages
- **Addresses**: Unique identifiers for engines that enable message routing
- **Messages**: Typed data structures exchanged between engines
- **Effects**: Actions that engines can perform (sending messages, updating state, creating engines, etc.)

## Usage Examples

### Defining an Engine Type

There are two approaches to defining engines: using the DSL macros or manual implementation.

#### Using the DSL (Recommended when working correctly)

```elixir
defmodule MyApp.KVStoreEngine do
  use EngineSystem.Engine.DSL
  
  defengine MyApp.KVStore, version: "1.0" do
    # Configuration spec defines metadata for the engine
    config do
      %{parent: nil, mode: :process, type: :read_write}
    end
    
    # Environment defines the initial state of the engine
    env do
      %{store: %{}, access_count: %{}}
    end
    
    # Message interface defines the messages this engine can handle
    messages do
      message :put, params: [:key, :value]
      message :get, params: [:key]
      message :delete, params: [:key]
      message :result, params: [:value_option]
    end
    
    # Behavior defines how the engine reacts to messages
    behaviour do
      guarded_action :put, [key, value], env: e do
        [
          {:update, put_in(e.store, [key], value)},
          {:send, sender, {:result, :ok}}
        ]
      end
      
      guarded_action :get, [key], env: e, when: is_map_key(e.store, key) do
        [
          {:update, Map.update(e, :access_count, %{}, fn counts ->
            Map.update(counts, key, 1, &(&1 + 1))
          end)},
          {:send, sender, {:result, Map.get(e.store, key)}}
        ]
      end
      
      guarded_action :get, [key], env: e do
        [
          {:send, sender, {:result, nil}}
        ]
      end
      
      guarded_action :delete, [key], env: e do
        [
          {:update, %{e | store: Map.delete(e.store, key)}},
          {:send, sender, {:result, :ok}}
        ]
      end
    end
  end
end
```


### Starting the System

Before using engines, you need to start the `EngineSystem`:

```elixir
EngineSystem.start()
```


### Creating an Engine Instance

```elixir
# Create an instance of your engine
{:ok, kv_address} = EngineSystem.create_engine({MyApp.KVStore, "1.0"}, %{})
```

### Sending Messages to Engines

```elixir
# Send an asynchronous message
EngineSystem.send_message(kv_address, {:put, :name, "Alice"})

# Send a synchronous message (waiting for a response)
result = EngineSystem.send_message_sync(kv_address, {:get, :name})
IO.puts("Got result: #{inspect(result)}")
```

### Getting Engine and System Information

```elixir
# Get info about a specific engine
{:ok, engine_info} = EngineSystem.get_engine_info(kv_address)

# List all engine instances
{:ok, engines} = EngineSystem.list_engines()

# List all engine types
{:ok, engine_types} = EngineSystem.list_engine_types()

# Get system info
{:ok, system_info} = EngineSystem.get_system_info()
```

## Included Examples

The library comes with example implementations to help you get started:

### KVStore Example

A simple key-value store engine that supports:
- Putting values with keys
- Getting values by key
- Deleting keys

Run the example:

```elixir
Examples.KVStoreDemo.run()
```

### SimpleKV Example

A more minimal key-value store implementation:

```elixir
Examples.SimpleKVDemo.run()
```
