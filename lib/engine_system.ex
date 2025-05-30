defmodule EngineSystem do
  @moduledoc """
  I am the main EngineSystem module.

  I provide the primary public API for the engine system, delegating to
  EngineSystem.API for the actual implementation.

  ## Public API

  - `start/0` - Start the EngineSystem application
  - `stop/0` - Stop the EngineSystem application
  - `spawn_engine/1..6` - Spawn engine instances with optional custom mailbox engines
  - `spawn_engine_with_mailbox/1` - Spawn with explicit mailbox configuration
  - `send_message/2..3` - Send messages between engines
  - `terminate_engine/1` - Terminate engine instances
  - `register_spec/1` - Register engine specifications
  - `lookup_spec/1..2` - Look up engine specifications
  - `list_instances/0` - List running instances
  - `list_specs/0` - List registered specifications
  - `lookup_instance/1` - Look up instance information
  - `lookup_address_by_name/1` - Look up addresses by name
  - `get_system_info/0` - Get system information
  - `fresh_id/0` - Generate unique IDs
  - `validate_message/2` - Validate messages
  - `clean_terminated_engines/0` - Clean up terminated engines
  """

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
end
