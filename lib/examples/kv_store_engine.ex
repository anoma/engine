use EngineSystem

defengine Examples.KVStoreEngine do
  @moduledoc """
  ## Who I Am

  I am a stateful key-value store engine that maintains persistent data across
  message interactions. I demonstrate fundamental data management patterns and
  serve as the foundation for understanding how engines can provide storage
  services within the EngineSystem architecture.

  ## My Purpose

  I serve multiple critical roles in distributed systems:
  - **Data Persistence**: I maintain key-value pairs across message interactions
  - **Storage Service**: I provide reliable data storage for other engines and components
  - **State Management Example**: I demonstrate how engines maintain complex internal state
  - **CRUD Pattern Demonstration**: I implement standard create, read, update, delete operations
  - **Analytics Foundation**: I track access patterns to provide usage insights

  I'm particularly valuable as a building block for more complex storage systems
  and as an educational example of stateful engine design.

  ## My Internal State

  I maintain two primary state components that persist across all operations:

  ### `store` - Primary Data Storage
  A map containing all my key-value pairs. This is where your data lives,
  organized as `%{key1 => value1, key2 => value2, ...}`.

  ### `access_counts` - Usage Analytics
  A map tracking how many times each key has been accessed, organized as
  `%{key1 => count1, key2 => count2, ...}`. This enables usage monitoring
  and access pattern analysis.

  ## Public API (Message Interface)

  I handle three primary CRUD operations with consistent response patterns:

  ### `:put` - Store Data
  **Request Format**: `{:put, %{key: atom, value: any}}`
  **Response Format**: `:ack`
  **Purpose**: Store a key-value pair in my internal storage

  ### `:get` - Retrieve Data
  **Request Format**: `{:get, %{key: atom}}`
  **Response Format**: `{:result, value}` (value is `nil` if key doesn't exist)
  **Purpose**: Retrieve a value by its key from storage

  ### `:delete` - Remove Data
  **Request Format**: `{:delete, %{key: atom}}`
  **Response Format**: `:ack`
  **Purpose**: Remove a key-value pair from storage completely

  ## Message Handling

  Here's exactly what happens when I receive each message type:

  ### When I Receive `:put` Messages

  1. **Key-Value Extraction**: I extract the `key` and `value` from the message payload
  2. **Data Storage**: I add/update the key-value pair in my `store` map using `Map.put/3`
  3. **State Update**: I create new environment state with the updated store
  4. **Persistence**: I apply the state change using the `:update_environment` effect
  5. **Acknowledgment**: I send `:ack` back to the sender confirming successful storage

  ```elixir
  # Input:  {:put, %{key: :username, value: "alice"}}
  # Process: store = Map.put(store, :username, "alice")
  # State:  %{store: %{username: "alice"}, access_counts: %{}}
  # Output: :ack sent back to sender
  ```

  ### When I Receive `:get` Messages

  1. **Key Extraction**: I extract the `key` from the message payload
  2. **Value Lookup**: I retrieve the value using `Map.get(store, key)`
  3. **Default Handling**: If the key doesn't exist, I return `nil` as the value
  4. **No State Change**: I don't modify my internal state for read operations
  5. **Result Response**: I send `{:result, value}` back to the sender

  ```elixir
  # Input:  {:get, %{key: :username}}
  # Process: value = Map.get(store, :username) # Returns "alice" or nil
  # State:  Unchanged (read-only operation)
  # Output: {:result, "alice"} sent back to sender
  ```

  ### When I Receive `:delete` Messages

  1. **Key Extraction**: I extract the `key` to be deleted from the payload
  2. **Data Removal**: I remove the key-value pair using `Map.delete(store, key)`
  3. **State Cleanup**: I create new environment state with the updated store
  4. **Persistence**: I apply the state change using the `:update_environment` effect
  5. **Acknowledgment**: I send `:ack` confirming successful deletion

  ```elixir
  # Input:  {:delete, %{key: :username}}
  # Process: store = Map.delete(store, :username)
  # State:  %{store: %{}, access_counts: %{}}
  # Output: :ack sent back to sender
  ```

  ## State Management Patterns

  I demonstrate several important state management patterns:

  ### Immutable Updates
  I never modify my state directly. Instead, I create new state objects and
  apply them atomically using the `:update_environment` effect.

  ### Atomic Operations
  Each message handler completes fully or not at all. There are no partial
  state updates that could leave me in an inconsistent state.

  ### Read-Only Operations
  My `:get` operations don't modify state, demonstrating how to handle
  queries without side effects.

  ### Consistent Responses
  I always acknowledge write operations with `:ack` and return read results
  with `{:result, value}`, providing predictable response patterns.

  ## Usage Examples

  ### Basic Storage Operations
  ```elixir
  # Spawn me
  {:ok, kv_addr} = EngineSystem.API.spawn_engine(Examples.KVStoreEngine)

  # Store some data
  EngineSystem.API.send_message(kv_addr, {:put, %{key: :user_name, value: "Alice"}})
  # I respond with: :ack

  EngineSystem.API.send_message(kv_addr, {:put, %{key: :user_age, value: 30}})
  # I respond with: :ack

  # Retrieve data
  EngineSystem.API.send_message(kv_addr, {:get, %{key: :user_name}})
  # I respond with: {:result, "Alice"}

  EngineSystem.API.send_message(kv_addr, {:get, %{key: :nonexistent}})
  # I respond with: {:result, nil}
  ```

  ### Data Management Workflow
  ```elixir
  # Store user profile
  EngineSystem.API.send_message(kv_addr, {:put, %{key: :profile, value: %{name: "Bob", role: "admin"}}})

  # Retrieve and use the profile
  EngineSystem.API.send_message(kv_addr, {:get, %{key: :profile}})
  # I respond with: {:result, %{name: "Bob", role: "admin"}}

  # Clean up when done
  EngineSystem.API.send_message(kv_addr, {:delete, %{key: :profile}})
  # I respond with: :ack
  ```

  ## Integration Scenarios

  I'm particularly useful in these scenarios:
  - **Session Storage**: Maintaining user session data across requests
  - **Configuration Management**: Storing and retrieving application settings
  - **Caching Layer**: Providing fast access to frequently used data
  - **Temporary Storage**: Managing transient data during complex operations
  - **Inter-Engine Communication**: Sharing data between different engines
  - **State Synchronization**: Coordinating state across distributed components

  ## Extensibility Foundation

  My simple, clean design makes me an excellent foundation for more advanced storage engines:

  ### Potential Extensions
  - **Persistence**: Add disk-based storage for durability
  - **Replication**: Distribute data across multiple instances
  - **Expiration**: Add TTL (time-to-live) support for automatic cleanup
  - **Indexing**: Add secondary indexes for efficient querying
  - **Transactions**: Implement multi-operation atomic transactions
  - **Compression**: Add data compression for large values

  ### Analytics Expansion
  - **Access Tracking**: Currently track access counts (foundation is there)
  - **Performance Metrics**: Track operation latency and throughput
  - **Usage Patterns**: Analyze hot/cold data access patterns

  ## Design Philosophy

  I embody key principles of stateful engine design:
  - **State Isolation**: My state is completely isolated from other engines
  - **Atomic Operations**: Each operation completes fully or fails completely
  - **Consistent Interface**: I provide uniform, predictable responses
  - **Simplicity**: My interface is minimal but complete for basic storage needs
  - **Extensibility**: My design allows for easy enhancement and specialization

  I serve as both a practical storage utility and an educational foundation
  for understanding how to build stateful, data-centric engines within the
  EngineSystem architecture.
  """

  version("1.0.0")
  # This is a processing engine
  mode(:process)

  interface do
    message(:put, key: :atom, value: :any)
    message(:get, key: :atom)
    message(:delete, key: :atom)
    message(:result, value: :any)
    message(:ack)
  end

  env do
    %{store: %{}, access_counts: %{}}
  end

  behaviour do
    on_message :put, %{key: key, value: value}, _config, env, sender do
      new_store = Map.put(env.store, key, value)
      new_env = %{env | store: new_store}
      {:ok, [{:update_environment, new_env}, {:send, sender, :ack}]}
    end

    on_message :get, %{key: key}, _config, env, sender do
      value = Map.get(env.store, key)
      {:ok, [{:send, sender, {:result, value}}]}
    end

    on_message :delete, %{key: key}, _config, env, sender do
      new_store = Map.delete(env.store, key)
      new_env = %{env | store: new_store}
      {:ok, [{:update_environment, new_env}, {:send, sender, :ack}]}
    end
  end
end
