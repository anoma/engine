defmodule EngineSystem do
  @moduledoc """
  I am the main EngineSystem module and primary entry point for the Engine System library.

  ## Overview

  EngineSystem is a comprehensive implementation of the Engine Model in Elixir,
  following the formal specification described in [Dynamic Effective Timed Communication
  Systems](https://zenodo.org/records/14984148). I provide a complete actor-like system
  with explicit mailbox-as-actors separation, type-safe message passing, and
  effectful actions through a user-friendly DSL.

  ##  Quick Start

  **For the complete interactive tutorial with runnable examples**, see the
  [**Livebook Tutorial**](README.livemd) which includes:
  - Step-by-step guided examples
  - Interactive code cells you can run
  - Real-world usage patterns
  - System management examples
  - Advanced patterns and best practices

  ### Basic Usage

  The recommended approach is to use `use EngineSystem`:

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

  This single import gives you access to:
  - **DSL macros** for defining engines (`defengine`, `version`, `config`, etc.)
  - **Utility functions** for message processing and validation
  - **API functions** for system management, engine lifecycle, and communication



  ## Key Features

  ### Engine Definition DSL

  User-friendly macro system for defining engines with compile-time validation:

  ```elixir
  defengine KVStore do
    version "1.0.0"

    config do
      %{max_size: 1000, timeout: 30.0}
    end

    interface do
      message :put, key: :atom, value: :any
      message :get, key: :atom
      message :result, value: {:option, :any}
    end

    behaviour do
      on_message :put, %{key: key, value: value}, _config, env, sender do
        new_env = %{env | store: Map.put(env.store, key, value)}
        {:ok, [
          {:update_environment, new_env},
          {:send, sender, :ack}
        ]}
      end
    end
  end
  ```

  ### Mailbox-as-Actors Pattern

  First-class mailbox engines that handle message reception and validation:

  - Independent message filtering and queueing policies
  - Backpressure management via demand-driven flow
  - Contract checking against processing engine interfaces

  ### Type-Safe Messaging

  Interface validation and message contracts ensure system reliability:

  ```elixir
  # Validate messages before sending
  case validate_message(engine_address, {:get, %{key: :my_key}}) do
    :ok -> send_message(engine_address, {:get, %{key: :my_key}})
    {:error, reason} -> handle_invalid_message(reason)
  end
  ```

  ### Effect System

  Composable effects for state management and communication:

  ```elixir
  {:ok, [
    {:update_environment, new_env},
    {:send, target_address, response},
    {:spawn, NewEngine, config, environment}
  ]}
  ```

  ### System Management

  Comprehensive lifecycle and monitoring APIs:

  - System health monitoring

  ```elixir
  system_info = get_system_info()
  IO.puts("Running engines: \#{system_info.running_instances}")

  ```

  -  Cleanup and maintenance

  ```elixir
  cleaned = clean_terminated_engines()
  IO.puts("Cleaned up \#{cleaned} terminated engines")
  ```

  ## API Reference

  ### System Management
  - `start/0` - Start the EngineSystem application
  - `stop/0` - Stop the EngineSystem application gracefully
  - `get_system_info/0` - Get comprehensive system health and metrics
  - `clean_terminated_engines/0` - Clean up terminated engines from registry

  ### Engine Lifecycle
  - `spawn_engine/1..6` - Spawn engine instances with flexible configuration
  - `spawn_engine_with_mailbox/1` - Spawn with explicit mailbox configuration
  - `terminate_engine/1` - Gracefully terminate engine instances

  ### Communication
  - `send_message/2..3` - Send messages between engines with optional sender
  - `validate_message/2` - Validate messages against engine interface contracts

  ### Registry and Discovery
  - `register_spec/1` - Register engine specifications for spawning
  - `lookup_spec/1..2` - Look up engine specifications by name/version
  - `list_instances/0` - List all running engine instances with metadata
  - `list_specs/0` - List all registered engine specifications
  - `lookup_instance/1` - Get detailed instance information by address
  - `lookup_address_by_name/1` - Look up addresses by registered names

  ### Interface Utilities
  - `has_message?/3` - Check if an engine supports a specific message tag
  - `get_message_fields/3` - Get field specifications for message tags
  - `get_message_tags/2` - Get all supported message tags for an engine
  - `get_instance_message_tags/1` - Get message tags for running instances

  ## DSL Macros

  When you `use EngineSystem`, you get access to all the DSL macros:
  - `defengine/2` - Define a new engine with configuration options
  - `version/1` - Set engine version for registry and compatibility
  - `config/1` - Define engine configuration structure and defaults
  - `env/1` - Define engine environment (state) structure and defaults
  - `interface/1` - Define message interface with type specifications
  - `behaviour/1` - Define engine behavior rules and message handlers

  ## Utility Functions

  Common utilities for engine development:
  - `validate_message_for_pe/2` - Validate messages against processing engine specs
  - `extract_messages/3` - Extract messages from queues with filtering support
  - `apply_filter/2` - Apply message filters safely with error handling
  - `extract_message_tag/1` - Extract message tags from various payload formats
  - `validate_address/1` - Validate engine address format and structure
  - `fresh_id/0` - Generate globally unique identifiers

  ## Examples and Patterns

  The library includes comprehensive examples in the **Examples** section:
  - **Simple Echo Engine** - Basic message echoing
  - **Stateless Calculator** - Functional computation engine
  - **Stateful Counter** - State management patterns
  - **Key-Value Store** - Advanced configuration and error handling
  - **Ping/Pong System** - Inter-engine communication patterns

  ## Architecture Notes

  EngineSystem implements a clean separation between:
  - **Processing Engines** - Business logic and state management
  - **Mailbox Engines** - Message queuing, filtering, and delivery
  - **System Registry** - Engine lifecycle and discovery
  - **Supervision Tree** - Fault tolerance and recovery

  For detailed architecture information and formal model compliance,
  see the research papers and the interactive tutorial.

  ## Getting Help

  - **[Interactive Tutorial](README.livemd)** - Best place to start learning
  - **API Reference** - Complete function documentation (this site)
  """

  @doc false
  defmacro __using__(_opts) do
    quote do
      # Import DSL macros from EngineSystem.Engine.DSL
      import EngineSystem.Engine.DSL

      # Import utility functions from EngineSystem.Engine
      import EngineSystem.Engine,
        only: [
          validate_message_for_pe: 2,
          extract_messages: 3,
          apply_filter: 2,
          extract_message_tag: 1,
          validate_address: 1,
          fresh_id: 0
        ]

      # Import all API functions from the main EngineSystem module
      import EngineSystem,
        only: [
          # System Management
          start: 0,
          stop: 0,
          get_system_info: 0,
          clean_terminated_engines: 0,

          # Engine Lifecycle
          spawn_engine: 1,
          spawn_engine: 2,
          spawn_engine: 3,
          spawn_engine: 4,
          spawn_engine: 5,
          spawn_engine: 6,
          spawn_engine_with_mailbox: 1,
          terminate_engine: 1,

          # Communication
          send_message: 2,
          send_message: 3,
          validate_message: 2,

          # Registry and Discovery
          register_spec: 1,
          lookup_spec: 1,
          lookup_spec: 2,
          list_instances: 0,
          list_specs: 0,
          lookup_instance: 1,
          lookup_address_by_name: 1,

          # Interface Utilities
          has_message?: 3,
          get_message_fields: 3,
          get_message_tags: 2,
          get_instance_message_tags: 1
        ]
    end
  end

  # Delegate all functions to EngineSystem.API
  defdelegate start(), to: EngineSystem.API, as: :start_system
  defdelegate stop(), to: EngineSystem.API, as: :stop_system

  defdelegate spawn_engine(engine_module), to: EngineSystem.API
  defdelegate spawn_engine(engine_module, config), to: EngineSystem.API
  defdelegate spawn_engine(engine_module, config, environment), to: EngineSystem.API
  defdelegate spawn_engine(engine_module, config, environment, name), to: EngineSystem.API

  defdelegate spawn_engine(engine_module, config, environment, name, mailbox_engine_module),
    to: EngineSystem.API

  defdelegate spawn_engine(
                engine_module,
                config,
                environment,
                name,
                mailbox_engine_module,
                mailbox_config
              ),
              to: EngineSystem.API

  defdelegate spawn_engine_with_mailbox(opts), to: EngineSystem.API

  defdelegate send_message(target_address, message_payload), to: EngineSystem.API
  defdelegate send_message(target_address, message_payload, sender_address), to: EngineSystem.API

  defdelegate terminate_engine(address), to: EngineSystem.API
  defdelegate register_spec(spec), to: EngineSystem.API
  defdelegate lookup_spec(name), to: EngineSystem.API
  defdelegate lookup_spec(name, version), to: EngineSystem.API
  defdelegate list_instances(), to: EngineSystem.API
  defdelegate list_specs(), to: EngineSystem.API
  defdelegate lookup_instance(address), to: EngineSystem.API
  defdelegate lookup_address_by_name(name), to: EngineSystem.API
  defdelegate get_system_info(), to: EngineSystem.API
  defdelegate fresh_id(), to: EngineSystem.API
  defdelegate validate_message(engine_address, message), to: EngineSystem.API
  defdelegate clean_terminated_engines(), to: EngineSystem.API

  # Interface Utilities
  defdelegate has_message?(name, version, tag), to: EngineSystem.API
  defdelegate get_message_fields(name, version, tag), to: EngineSystem.API
  defdelegate get_message_tags(name, version), to: EngineSystem.API
  defdelegate get_instance_message_tags(address), to: EngineSystem.API
end
