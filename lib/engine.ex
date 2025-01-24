defmodule Engine do
  @moduledoc """
  Engine: A type-safe actor model for Elixir. (Work in progress)

  An engine is a dynamic entity that can process messages and maintain state in
  a type-safe way. Each engine has the following components (some are internal):

  ## Core Components

  - Status: Running, Dead, or Suspended (internal)
  - Message Interface: A strictly typed collection of messages the engine can
    process. A message type consists of a tag and may have a payload.
    For example, a message type could be `:tick` with a payload of `%{count:
    :integer}`.

  - Configuration (immutable):
    - Parent: Optional parent engine that spawned this engine (internal)
    - Pid: Unique engine identifier (internal)
    - Node: Virtual location where engine runs (internal)
    - Name: Human-readable alias for the engine
    - Config: Engine-specific configuration
  - Environment:
    - State: Internal mutable state with type guarantees
    - Mailbox Cluster: Organized collection of typed message queues
    - Address Book: Set of known engines it can interact with
  - Behavior: Defines how engine reacts to messages through:
    - Guard: Type-safe predicate that controls when actions execute
    - Effects: Type-safe actions the engine can perform

  ## Message Processing

  The engine processes messages from its mailbox by:
  1. Receiving a typed message
  2. Evaluating guard to determine valid action
  3. Executing effects if guard is satisfied
  4. Updating state if needed
  5. Sending any response messages

  ## Guard

  A guard is a type-safe predicate that determines if an action should execute:

      @type guard(state, msg, config, result) ::
        (msg -> env(state, msg) -> config -> {:ok, result} | nil)

  ## Effects

  Effects are the type-safe actions an engine can perform:

      @type effect(state, env, msg) ::
        {:send_msg, msg}           | # Send typed message to another engine
        {:update_state, state}     | # Update internal state
        {:spawn_engine, env}       | # Create new engine
        {:chain, list(effect)}     | # Chain multiple effects
        {:schedule, %{             | # Schedule future action
          trigger: time_trigger(),
          action: effect
        }}

  Messages must be well-structured and contain:
  - Target engine's pid
  - Message payload matching target's message interface

  The engine's behavior maps guard evaluation to effects:

      @type engine_behaviour(state, env, msg, config, result) ::
        (guard(state, msg, config, result) -> effect(state, env, msg))
  """

  defmacro __using__(_opts) do
    quote do
      # A message tag is a unique identifier for a message type
      Module.register_attribute(__MODULE__, :message_tags, accumulate: false, persist: false)
      # The message type consists of a tag and may have a payload
      Module.register_attribute(__MODULE__, :message_types, accumulate: false, persist: false)

      @message_tags []
      @message_types []

      # Configuration is a map of key-value pairs
      @configuration []

      # Environment is a map of key-value pairs
      @environment []

      # Guard is a list of guards
      @guard []

      import Engine

      @before_compile Engine
    end
  end

  defmacro defmsg(name, type_payload \\ []) do
    quote do
      # Define type for this message
      @type unquote(name)() :: unquote(Macro.escape(type_payload))

      # Check if message tag already exists
      tname = unquote(name)

      if tname not in @message_tags do
        @message_tags [tname | @message_tags]
      else
        raise CompileError, description: "Message tag <#{tname}> already defined"
      end

      @message_types [{tname, unquote(Macro.escape(type_payload))} | @message_types]
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      def message_types, do: @message_types
      def message_tags, do: @message_tags

      if Enum.empty?(@message_types) do
        msg = """
        An engine must define at least one message type in its message interface using defmsg/2. Example:
        > defmsg(:tick, %{count: :integer})
        > defmsg(:stop)
        """

        raise CompileError, description: msg
      end
    end
  end
end
