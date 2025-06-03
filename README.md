# EngineSystem

[![CI](https://github.com/anoma/engine/actions/workflows/ci.yml/badge.svg)](https://github.com/anoma/engine/actions/workflows/ci.yml)
[![Hex.pm](https://img.shields.io/hexpm/v/engine_system.svg)](https://hex.pm/packages/engine_system)
[![Documentation](https://img.shields.io/badge/docs-latest-blue.svg)](https://hexdocs.pm/engine_system/)

A formal model-adherent implementation of the Engine Model in Elixir, following the specification described in [Dynamic Effective Timed Communication Systems](https://zenodo.org/records/14984148).

## 🚀 Quick Start

### Interactive Tutorial (Recommended)

**For the best learning experience**, open our **[Interactive Livebook Tutorial](README.livemd)**:

```bash
make livebook
# OR if you have Livebook installed:
livebook server README.livemd
```

The tutorial includes:
- 📚 Step-by-step guided examples
- 🏃‍♂️ Runnable code cells
- 🎯 Real-world usage patterns  
- 🔧 System management examples
- 🏗️ Advanced patterns and best practices

### Installation

Add `engine_system` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:engine_system, "~> 0.1.0"}
  ]
end
```

### Basic Usage

```elixir
use EngineSystem

# Start the system
{:ok, _} = start()

# Define an engine using the DSL
defengine MyEngine do
  version "1.0.0"
  
  interface do
    message :ping
    message :pong
  end
  
  behaviour do
    on_message :ping, _msg, _config, _env, sender do
      {:ok, [{:send, sender, :pong}]}
    end
  end
end

# Spawn and interact with engines
{:ok, address} = spawn_engine(MyEngine)
send_message(address, {:ping, %{}})
```

## 📚 Documentation

- **[📓 Interactive Tutorial](README.livemd)** - Complete hands-on guide
- **[📖 API Documentation](https://hexdocs.pm/engine_system/)** - Complete reference

## Key Features

- **🎭 Engine Definition DSL** - User-friendly macro system for defining engines
- **📮 Mailbox-as-Actors** - First-class mailbox engines for message handling  
- **🔒 Type-Safe Messaging** - Interface validation and message contracts
- **⚡ Effect System** - Composable effects for state and communication
- **🏥 System Management** - Comprehensive lifecycle and monitoring APIs
- **🛡️ Fault Tolerance** - Supervision trees and error recovery

## Architecture

EngineSystem implements a clean separation between:

- **Processing Engines** - Business logic and state management (GenStage consumers)
- **Mailbox Engines** - Message queuing, filtering, and delivery (GenStage producers)  
- **System Registry** - Engine lifecycle and discovery
- **Supervision Tree** - Fault tolerance and recovery

## Examples

The library includes comprehensive examples:

- **Simple Echo Engine** - Basic message echoing
- **Stateless Calculator** - Functional computation patterns
- **Stateful Counter** - State management examples
- **Key-Value Store** - Advanced configuration and error handling
- **Ping/Pong System** - Inter-engine communication patterns

All examples are interactive in the [Livebook Tutorial](README.livemd).

## Development

```bash
# Get dependencies
mix deps.get

# Run tests
mix test

# Generate documentation
mix docs

# Run the interactive tutorial
make livebook
```

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Research

This implementation follows the formal specification described in:

- [Dynamic Effective Timed Communication Systems](https://zenodo.org/records/14984148)
- [Mailbox-as-Actors (under review)](https://www.overleaf.com/read/fzvnxbgkhhzd#17b19a)

## Support

- 📓 **[Start with the Interactive Tutorial](README.livemd)**
- 📖 **[Browse the API Documentation](https://hexdocs.pm/engine_system/)**
- 🐛 **[Report Issues](https://github.com/anoma/engine/issues)**
- 💬 **[Discussions](https://github.com/anoma/engine/discussions)**

---

**Happy engine building!** 🚀 