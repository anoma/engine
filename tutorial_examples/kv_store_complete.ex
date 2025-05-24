defmodule TutorialExamples.CompleteKVStore do
  @moduledoc """
  A complete key-value store engine demonstrating all EngineSystem features.

  This example shows:
  - Configuration with read-only mode
  - Environment with store and access tracking
  - Complete message interface
  - Sophisticated guarded actions with guards
  - Multiple effect types
  """

  use EngineSystem.Engine.DSL

  defengine TutorialExamples.KVStore, version: "2.0" do
    # Configuration defines engine metadata and settings
    config do
      %{
        parent: nil,                    # Parent engine reference
        mode: :process,                 # Execution mode
        read_only: false,              # Whether writes are allowed
        max_size: 1000,                # Maximum number of entries
        ttl_seconds: 3600              # Time-to-live for entries
      }
    end

    # Environment defines the engine's local state
    env do
      %{
        store: %{},                    # Key-value storage
        access_count: %{},             # Access frequency tracking
        timestamps: %{},               # Entry creation timestamps
        size: 0                        # Current number of entries
      }
    end

    # Message interface defines what messages this engine handles
    messages do
      # Basic operations
      message :put, params: [:key, :value]
      message :get, params: [:key]
      message :delete, params: [:key]

      # Advanced operations
      message :exists, params: [:key]
      message :size, params: []
      message :keys, params: []
      message :clear, params: []

      # Response messages
      message :result, params: [:value]
      message :ack, params: []
      message :error, params: [:reason]
    end

    # Behaviour defines how the engine responds to messages
    behaviour do
      # PUT: Store a key-value pair (only if not read-only and under size limit)
      guarded_action :put, [key, value],
        env: e, config: c,
        when: not c.read_only and e.size < c.max_size do

        current_time = System.system_time(:second)
        new_store = Map.put(e.store, key, value)
        new_timestamps = Map.put(e.timestamps, key, current_time)
        new_access_count = Map.update(e.access_count, key, 1, &(&1 + 1))
        new_size = if Map.has_key?(e.store, key), do: e.size, else: e.size + 1

        [
          {:update, %{
            e |
            store: new_store,
            timestamps: new_timestamps,
            access_count: new_access_count,
            size: new_size
          }},
          {:send, sender, {:ack}}
        ]
      end

      # GET: Retrieve a value (only if key exists and not expired)
      guarded_action :get, [key], env: e, config: c, when: is_map_key(e.store, key) do
        current_time = System.system_time(:second)
        timestamp = Map.get(e.timestamps, key, current_time)

        # Check if entry has expired
        if current_time - timestamp > c.ttl_seconds do
          # Entry expired, remove it
          new_store = Map.delete(e.store, key)
          new_timestamps = Map.delete(e.timestamps, key)
          new_access_count = Map.delete(e.access_count, key)

          [
            {:update, %{
              e |
              store: new_store,
              timestamps: new_timestamps,
              access_count: new_access_count,
              size: e.size - 1
            }},
            {:send, sender, {:result, nil}}
          ]
        else
          # Entry valid, return value and update access count
          value = Map.get(e.store, key)
          new_access_count = Map.update(e.access_count, key, 1, &(&1 + 1))

          [
            {:update, %{e | access_count: new_access_count}},
            {:send, sender, {:result, value}}
          ]
        end
      end

      # GET: Handle case when key doesn't exist
      guarded_action :get, [key], env: e, when: not is_map_key(e.store, key) do
        [
          {:send, sender, {:result, nil}}
        ]
      end

      # DELETE: Remove a key-value pair (only if not read-only)
      guarded_action :delete, [key],
        env: e, config: c,
        when: not c.read_only and is_map_key(e.store, key) do

        new_store = Map.delete(e.store, key)
        new_timestamps = Map.delete(e.timestamps, key)
        new_access_count = Map.delete(e.access_count, key)

        [
          {:update, %{
            e |
            store: new_store,
            timestamps: new_timestamps,
            access_count: new_access_count,
            size: e.size - 1
          }},
          {:send, sender, {:ack}}
        ]
      end

      # DELETE: Handle case when key doesn't exist
      guarded_action :delete, [key], env: e, when: not is_map_key(e.store, key) do
        [
          {:send, sender, {:error, :key_not_found}}
        ]
      end

      # EXISTS: Check if a key exists (and is not expired)
      guarded_action :exists, [key], env: e, config: c do
        current_time = System.system_time(:second)

        case Map.get(e.timestamps, key) do
          nil ->
            [{:send, sender, {:result, false}}]

          timestamp when current_time - timestamp > c.ttl_seconds ->
            # Expired, clean up and return false
            new_store = Map.delete(e.store, key)
            new_timestamps = Map.delete(e.timestamps, key)
            new_access_count = Map.delete(e.access_count, key)

            [
              {:update, %{
                e |
                store: new_store,
                timestamps: new_timestamps,
                access_count: new_access_count,
                size: e.size - 1
              }},
              {:send, sender, {:result, false}}
            ]

          _timestamp ->
            [{:send, sender, {:result, true}}]
        end
      end

      # SIZE: Return current store size
      guarded_action :size, [], env: e do
        [
          {:send, sender, {:result, e.size}}
        ]
      end

      # KEYS: Return all current keys
      guarded_action :keys, [], env: e do
        keys = Map.keys(e.store)
        [
          {:send, sender, {:result, keys}}
        ]
      end

      # CLEAR: Remove all entries (only if not read-only)
      guarded_action :clear, [], env: e, config: c, when: not c.read_only do
        [
          {:update, %{
            e |
            store: %{},
            timestamps: %{},
            access_count: %{},
            size: 0
          }},
          {:send, sender, {:ack}}
        ]
      end

      # CLEAR: Handle read-only mode
      guarded_action :clear, [], config: c, when: c.read_only do
        [
          {:send, sender, {:error, :read_only_mode}}
        ]
      end
    end
  end
end
