defmodule EngineSystem do
  @moduledoc """
  I am the main EngineSystem module and primary entry point for the Engine System library.

  ## Usage

  The recommended approach is to use `use EngineSystem`:

  ```elixir
  use EngineSystem

  defengine MyEngine do
    version "1.0.0"
    # ... rest of engine definition
  end

  # You can now also use all API functions directly
  {:ok, address} = spawn_engine(MyEngine)
  send_message(address, {:ping, %{}})
  ```

  This single import gives you access to:
  - **DSL macros** for defining engines (`defengine`, `version`, `config`, etc.)
  - **Utility functions** for message processing and validation
  - **API functions** for system management, engine lifecycle, and communication

  ## DSL Macros

  When you `use EngineSystem`, you get access to all the DSL macros:
  - `defengine/2` - Define a new engine
  - `version/1` - Set engine version
  - `config/1` - Define engine configuration
  - `env/1` - Define engine environment
  - `interface/1` - Define message interface
  - `behaviour/1` - Define engine behavior

  ## Utility Functions

  Common utilities for engine development:
  - `validate_message_for_pe/2` - Validate messages against processing engine specs
  - `extract_messages/3` - Extract messages from queues with filtering
  - `apply_filter/2` - Apply message filters safely
  - `extract_message_tag/1` - Extract message tags from payloads
  - `validate_address/1` - Validate engine address format
  - `fresh_id/0` - Generate unique identifiers

  ## API Functions

  ### System Management
  - `start/0` - Start the EngineSystem application
  - `stop/0` - Stop the EngineSystem application
  - `get_system_info/0` - Get system information
  - `clean_terminated_engines/0` - Clean up terminated engines

  ### Engine Lifecycle
  - `spawn_engine/1..6` - Spawn engine instances with optional custom mailbox engines
  - `spawn_engine_with_mailbox/1` - Spawn with explicit mailbox configuration
  - `terminate_engine/1` - Terminate engine instances

  ### Communication
  - `send_message/2..3` - Send messages between engines
  - `validate_message/2` - Validate messages against engine interface

  ### Registry and Discovery
  - `register_spec/1` - Register engine specifications
  - `lookup_spec/1..2` - Look up engine specifications
  - `list_instances/0` - List all running engine instances
  - `list_specs/0` - List all registered engine specifications
  - `lookup_instance/1` - Look up instance information by address
  - `lookup_address_by_name/1` - Look up addresses by registered name

  ### Interface Utilities
  - `has_message?/3` - Check if an engine specification supports a specific message tag
  - `get_message_fields/3` - Get the field specification for a message tag from an engine specification
  - `get_message_tags/2` - Get all message tags supported by an engine specification
  - `get_instance_message_tags/1` - Get all message tags supported by a running engine instance
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
