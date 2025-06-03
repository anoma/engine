# Changelog

All notable changes to the EngineSystem project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## v0.1.0

### Goals of this release

- **Engine Definition DSL**: User-friendly macro system for defining engines
- **Mailbox-as-Actors**: First-class mailbox engines for message handling
- **Type-Safe Messaging**: Interface validation and message contracts
- **Effect System**: Composable effects for state and communication
- **System Management**: Comprehensive lifecycle and monitoring APIs

### What's new?

- Initial implementation of the Engine Model, one single-node system with a single registry
- DSL for engine definition (`defengine` macro)
- Processing engines with GenStage consumers
- Mailbox engines with GenStage producers
- System registry for engine specifications and instances
- Message passing and validation system
- Configuration and environment management
- Effects system for state management and communication
- Comprehensive example engines (Echo, Calculator, Counter, KV Store)
- System lifecycle management
- Supervision tree with fault tolerance

### Documentation

- Comprehensive ExDoc documentation configuration
- Interactive Livebook tutorial integration (README.livemd)
- First-person documentation convention across all modules
- System management functions documentation with practical examples
- Enhanced API documentation with error handling examples
- Documentation guide for contributors
- Module grouping and navigation structure for better organization

### Examples Included

- Simple Echo Engine
- Stateless Calculator Engine  
- Stateful Counter Engine
- Advanced Key-Value Store Engine
- Ping/Pong Communication Examples
- Interactive Demo Systems

### Architecture

- Clean separation between processing and mailbox engines
- GenStage-based backpressure and demand management
- Registry-based instance and specification tracking
- Dynamic supervision for engine lifecycle management
- Formal model adherence with operational semantics

### Development Tools

- Credo for code quality
- Dialyzer for type checking
- Comprehensive test suite
- ExDoc documentation generation