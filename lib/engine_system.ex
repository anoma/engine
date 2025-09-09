defmodule EngineSystem do
  @moduledoc """
  I am the main entry point for the EngineSystem library, providing a comprehensive actor-like system with mailbox-as-actors separation and type-safe message passing.
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
