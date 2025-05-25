import EngineSystem.Engine.DSL

defengine Examples.KVStoreEngine do
  @moduledoc """
  Key-Value Store Engine implementing Example 2.4 from the formal paper.

  This demonstrates the complete formal specification from "ART-Mailboxes-actors/main.tex":

  ## Paper References

  - **Example 2.4**: Key-Value Store Engine specification
  - **Equation (2.1)**: Message interface MsgType_kv
  - **Equation (2.2)**: Configuration types C_kv
  - **Equation (2.3)**: Environment types L_kv
  - **Equations (2.4), (2.5), (2.6)**: Guarded actions for get, put, delete

  ## Message Interface (Equation 2.1)

  ```
  MsgType_kv := Put(Key×Value) | Get(Key) | Delete(Key) | Result(Option(Value))
  ```

  ## Configuration (Equation 2.2)

  ```
  C_kv := ReadOnly | ReadAppend | ReadModify | ReadWrite
  ```

  ## Environment (Equation 2.3)

  ```
  L_kv := (Key → Option(Value)) × (Key → ℕ)
  ```

  This serves as both a reference implementation of the paper's example and a
  demonstration of the EngineSystem DSL capabilities.
  """
  version("1.0.0")

  # Message interface implementing Equation (2.1) from the paper
  interface do
    # Get(Key)
    message(:get, key: :atom)
    # Put(Key×Value)
    message(:put, key: :atom, value: :any)
    # Delete(Key)
    message(:delete, key: :atom)
    # Result(Option(Value))
    message(:result, value: {:option, :any})
    # Acknowledgment message
    message(:ack)
  end

  # Configuration implementing Equation (2.2) from the paper
  # C_kv := ReadOnly | ReadAppend | ReadModify | ReadWrite
  config kv_config: %{access_mode: :read_write, max_size: 1000} do
    # Access mode constraint
    field(:access_mode, default: :read_write, type: :atom)
    # Additional constraint
    field(:max_size, default: 1000, type: :integer)
  end

  # Environment implementing Equation (2.3) from the paper
  # L_kv := (Key → Option(Value)) × (Key → ℕ)
  environment kv_env: %{store: %{}, access_counts: %{}} do
    # Key → Option(Value) mapping
    field(:store, default: %{}, type: :map)
    # Key → ℕ access counters
    field(:access_counts, default: %{}, type: :map)
  end

  message_filter(fn _msg, _config, _env -> true end)

  # Behaviour implementing guarded actions from Equations (2.4), (2.5), (2.6)
  behaviour do
    # Get operation implementing Equation (2.4) from the paper
    # Guard: check for Get tag and return key if found
    # Action: retrieve value, update access count, send result
    on_message :get do
      quote do
        # Extract key from message payload
        key =
          case msg_payload do
            {key} -> key
            key when is_atom(key) -> key
            _ -> nil
          end

        if key do
          # Get current store and access counts
          store = get_in(env_data.local_state, [:store]) || %{}
          access_counts = get_in(env_data.local_state, [:access_counts]) || %{}

          # Look up value
          value = Map.get(store, key)
          result_value = if value, do: {:some, value}, else: :none

          # Update access count
          new_count = Map.get(access_counts, key, 0) + 1
          new_access_counts = Map.put(access_counts, key, new_count)

          # Update environment with new access count
          new_local_state = %{
            store: store,
            access_counts: new_access_counts
          }

          new_env = %{env_data | local_state: new_local_state}

          # Create effects: update environment and send result
          effects = [
            {:update_environment, new_env}
          ]

          # Add send effect if we have a sender
          final_effects =
            if msg_sender_address do
              effects ++ [{:send, msg_sender_address, {:result, result_value}}]
            else
              effects
            end

          {:ok, final_effects}
        else
          # Invalid key, send error if we have a sender
          if msg_sender_address do
            {:ok, [{:send, msg_sender_address, {:result, :error}}]}
          else
            {:ok, [:noop]}
          end
        end
      end
    end

    # Put operation implementing Equation (2.5) from the paper
    # Guard: check if not read-only mode
    # Action: update store and acknowledge
    on_message :put do
      quote do
        # Check access mode from configuration
        access_mode = get_in(config_data.local_state, [:access_mode]) || :read_write

        case access_mode do
          :read_only ->
            # Read-only mode, reject the operation
            if msg_sender_address do
              {:ok, [{:send, msg_sender_address, {:error, :read_only}}]}
            else
              {:ok, [:noop]}
            end

          _ ->
            # Extract key and value from message payload
            {key, value} =
              case msg_payload do
                {key, value} -> {key, value}
                _ -> {nil, nil}
              end

            if key && value do
              # Get current store and access counts
              store = get_in(env_data.local_state, [:store]) || %{}
              access_counts = get_in(env_data.local_state, [:access_counts]) || %{}

              # Check max_size constraint
              max_size = get_in(config_data.local_state, [:max_size]) || 1000
              current_size = map_size(store)

              if current_size >= max_size && !Map.has_key?(store, key) do
                # Store is full and this is a new key
                if msg_sender_address do
                  {:ok, [{:send, msg_sender_address, {:error, :store_full}}]}
                else
                  {:ok, [:noop]}
                end
              else
                # Update store
                new_store = Map.put(store, key, value)

                # Update environment
                new_local_state = %{
                  store: new_store,
                  access_counts: access_counts
                }

                new_env = %{env_data | local_state: new_local_state}

                # Create effects
                effects = [{:update_environment, new_env}]

                # Add acknowledgment if we have a sender
                final_effects =
                  if msg_sender_address do
                    effects ++ [{:send, msg_sender_address, :ack}]
                  else
                    effects
                  end

                {:ok, final_effects}
              end
            else
              # Invalid payload
              if msg_sender_address do
                {:ok, [{:send, msg_sender_address, {:error, :invalid_payload}}]}
              else
                {:ok, [:noop]}
              end
            end
        end
      end
    end

    # Delete operation implementing Equation (2.6) from the paper
    # Guard: check if read-write mode
    # Action: remove from store and acknowledge
    on_message :delete do
      quote do
        # Check access mode from configuration
        access_mode = get_in(config_data.local_state, [:access_mode]) || :read_write

        case access_mode do
          mode when mode in [:read_only, :read_append] ->
            # Cannot delete in read-only or read-append modes
            if msg_sender_address do
              {:ok, [{:send, msg_sender_address, {:error, :insufficient_permissions}}]}
            else
              {:ok, [:noop]}
            end

          _ ->
            # Extract key from message payload
            key =
              case msg_payload do
                {key} -> key
                key when is_atom(key) -> key
                _ -> nil
              end

            if key do
              # Get current store and access counts
              store = get_in(env_data.local_state, [:store]) || %{}
              access_counts = get_in(env_data.local_state, [:access_counts]) || %{}

              # Remove from store and access counts
              new_store = Map.delete(store, key)
              new_access_counts = Map.delete(access_counts, key)

              # Update environment
              new_local_state = %{
                store: new_store,
                access_counts: new_access_counts
              }

              new_env = %{env_data | local_state: new_local_state}

              # Create effects
              effects = [{:update_environment, new_env}]

              # Add acknowledgment if we have a sender
              final_effects =
                if msg_sender_address do
                  effects ++ [{:send, msg_sender_address, :ack}]
                else
                  effects
                end

              {:ok, final_effects}
            else
              # Invalid key
              if msg_sender_address do
                {:ok, [{:send, msg_sender_address, {:error, :invalid_key}}]}
              else
                {:ok, [:noop]}
              end
            end
        end
      end
    end
  end
end
