defmodule EngineSystem do
  @moduledoc """
  I am the main facade for the EngineSystem.

  I provide a clean, user-friendly API for:
  - Starting and stopping the system
  - Spawning engine instances
  - Sending messages between engines
  - Managing engine specifications
  - Querying system state

  This implements the high-level interface to the actor model with explicit
  mailbox-as-actors separation as described in the formal specifications.
  """

  alias EngineSystem.{API, Lifecycle}

  # Lifecycle operations
  defdelegate start(), to: Lifecycle
  defdelegate stop(), to: Lifecycle

  # Core API operations
  defdelegate spawn_engine(engine_module, config \\ nil, environment \\ nil, name \\ nil), to: API
  defdelegate send_message(target_address, message_payload, sender_address \\ nil), to: API
  defdelegate terminate_engine(address), to: API

  # Specification management for transforming DSL-expressed engine
  defdelegate register_spec(spec), to: API
  defdelegate lookup_spec(name, version \\ nil), to: API
  defdelegate list_specs(), to: API

  # Instance management
  defdelegate list_instances(), to: API
  defdelegate lookup_instance(address), to: API
  defdelegate lookup_address_by_name(name), to: API

  # System utilities
  defdelegate get_system_info(), to: API
  defdelegate fresh_id(), to: API
  defdelegate validate_message(engine_address, message), to: API
  defdelegate clean_terminated_engines(), to: API
end
