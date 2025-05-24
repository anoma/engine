defmodule EngineSystem.Engine.EngineProcess.Types do
  @moduledoc """
  I define shared types used across the EngineProcess modules according to the formal Engine Model.

  This module centralizes type definitions to avoid duplication and ensure
  consistency across all EngineProcess-related modules. All types follow
  the formal specification from the Engine Model paper.
  """

  @typedoc """
  Engine address represents a unique identifier for an engine instance.
  """
  @type engine_address :: {:engine, node(), pos_integer()} | {:sender, pid()}

  @typedoc """
  Message ID is a unique identifier for a message.
  """
  @type message_id :: String.t()

  @typedoc """
  Timestamp represents time in milliseconds since epoch.
  """
  @type timestamp :: integer()

  @typedoc """
  Engine type name can be an atom or string.
  """
  @type engine_type_name :: atom() | String.t()

  @typedoc """
  Engine version is always a string.
  """
  @type engine_version :: String.t()

  @typedoc """
  Configuration is always a map.
  """
  @type config :: map()

  @typedoc """
  Environment can be any type as it's engine-specific.
  """
  @type environment :: any()

  @typedoc """
  Effect types matching the formal model (Definition 6.1).
  These are the primitive operations that engines can request the system to execute.
  """
  @type effect ::
          :noop
          | {:send, engine_address(), any()}
          | {:update, environment()}
          | {:spawn, {engine_type_name(), config(), environment()}}
          | {:mfilter, (any() -> boolean())}
          | :terminate
          | {:chain, effect(), effect()}

  @typedoc """
  Action results represent the possible return values from executing a guarded action.
  """
  @type action_result :: effect() | list(effect())

  @typedoc """
  Operational mode represents how the engine processes messages.
  """
  @type operational_mode :: :sync | :async
end
