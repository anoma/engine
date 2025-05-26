import EngineSystem.Engine.DSL

defengine Examples.PriorityChatEngine do
  @moduledoc """
  Priority Chat Engine demonstrating mailbox customization and filtering.

  This engine showcases:
  - Custom message filtering based on priority levels
  - Dynamic filter updates based on engine state
  - Message routing and broadcasting capabilities
  - Stateful conversation management

  ## Features

  - **Priority Filtering**: Messages with different priority levels (urgent, normal, low)
  - **Dynamic Filters**: Filter behavior changes based on engine state (busy, available, away)
  - **Conversation State**: Tracks active conversations and participants
  - **Broadcasting**: Can send messages to multiple recipients
  - **Presence Management**: Tracks user presence and availability

  ## Message Interface

  - `join_room(room_id, user_id)`: Join a chat room
  - `leave_room(room_id, user_id)`: Leave a chat room
  - `send_message(room_id, message, priority)`: Send a message with priority
  - `set_status(status)`: Set user status (available, busy, away)
  - `broadcast(room_id, message)`: Broadcast to all room members
  - `private_message(target_user, message, priority)`: Send private message

  This demonstrates advanced mailbox filtering where the filter function
  changes dynamically based on the engine's current state and configuration.
  """
  version("1.0.0")

  # Message interface with priority and routing capabilities
  interface do
    # Room management
    message(:join_room, room_id: :atom, user_id: :atom)
    message(:leave_room, room_id: :atom, user_id: :atom)

    # Messaging with priority
    message(:send_message, room_id: :atom, message: :binary, priority: :atom)
    message(:private_message, target_user: :atom, message: :binary, priority: :atom)
    message(:broadcast, room_id: :atom, message: :binary)

    # Status and presence
    message(:set_status, status: :atom)
    message(:get_status, user_id: :atom)

    # Responses
    message(:message_delivered, message_id: :binary)
    message(:status_response, user_id: :atom, status: :atom)
    message(:room_joined, room_id: :atom, user_id: :atom)
    message(:room_left, room_id: :atom, user_id: :atom)
    message(:error, reason: :atom)
  end

  # Configuration for chat behavior and filtering
  config chat_config: %{
           max_rooms: 10,
           max_room_size: 100,
           priority_filtering: true,
           status: :available
         } do
    field(:max_rooms, default: 10, type: :integer)
    field(:max_room_size, default: 100, type: :integer)
    field(:priority_filtering, default: true, type: :boolean)
    field(:status, default: :available, type: :atom)
  end

  # Environment tracking rooms, users, and conversations
  environment chat_env: %{
                rooms: %{},
                user_status: %{},
                active_conversations: %{},
                message_history: []
              } do
    field(:rooms, default: %{}, type: :map)
    field(:user_status, default: %{}, type: :map)
    field(:active_conversations, default: %{}, type: :map)
    field(:message_history, default: [], type: :list)
  end

  # Dynamic message filter that changes based on engine status and configuration
  message_filter(fn msg, config, env ->
    # Extract message details
    {tag, payload} =
      case msg do
        {tag, payload} -> {tag, payload}
        tag when is_atom(tag) -> {tag, %{}}
        _ -> {:unknown, %{}}
      end

    # Get current status from config
    current_status = get_in(config, [:local_state, :status]) || :available
    priority_filtering = get_in(config, [:local_state, :priority_filtering]) || true

    case current_status do
      :available ->
        # Accept all messages when available
        true

      :busy ->
        # When busy, only accept urgent messages and system messages
        if priority_filtering do
          case tag do
            # Always accept system/management messages
            tag when tag in [:join_room, :leave_room, :set_status, :get_status] ->
              true

            # For priority messages, check priority level
            :send_message ->
              priority = Map.get(payload, :priority, :normal)
              priority == :urgent

            :private_message ->
              priority = Map.get(payload, :priority, :normal)
              priority == :urgent

            # Reject broadcasts when busy
            :broadcast ->
              false

            # Accept responses
            tag when tag in [:message_delivered, :status_response, :room_joined, :room_left] ->
              true

            _ ->
              false
          end
        else
          # If priority filtering is disabled, accept all
          true
        end

      :away ->
        # When away, only accept urgent private messages and system messages
        case tag do
          # System messages always accepted
          tag when tag in [:set_status, :get_status] ->
            true

          # Only urgent private messages
          :private_message ->
            priority = Map.get(payload, :priority, :normal)
            priority == :urgent

          # Reject everything else
          _ ->
            false
        end

      _ ->
        # Unknown status, be conservative and reject
        false
    end
  end)

  # Behavior implementing chat functionality
  behaviour do
    # Join a chat room
    on_message :join_room do
      quote do
        room_id = Map.get(msg_payload, :room_id)
        user_id = Map.get(msg_payload, :user_id)

        if room_id && user_id do
          # Get current rooms and check limits
          rooms = get_in(env_data.local_state, [:rooms]) || %{}
          max_rooms = get_in(config_data.local_state, [:max_rooms]) || 10
          max_room_size = get_in(config_data.local_state, [:max_room_size]) || 100

          current_room = Map.get(rooms, room_id, %{members: [], created_at: DateTime.utc_now()})
          current_members = Map.get(current_room, :members, [])

          cond do
            # Check if user already in room
            user_id in current_members ->
              effects =
                if msg_sender_address do
                  [{:send, msg_sender_address, {:error, :already_in_room}}]
                else
                  [:noop]
                end

              {:ok, effects}

            # Check room size limit
            length(current_members) >= max_room_size ->
              effects =
                if msg_sender_address do
                  [{:send, msg_sender_address, {:error, :room_full}}]
                else
                  [:noop]
                end

              {:ok, effects}

            # Check total rooms limit
            map_size(rooms) >= max_rooms && !Map.has_key?(rooms, room_id) ->
              effects =
                if msg_sender_address do
                  [{:send, msg_sender_address, {:error, :too_many_rooms}}]
                else
                  [:noop]
                end

              {:ok, effects}

            true ->
              # Add user to room
              new_members = [user_id | current_members]
              updated_room = %{current_room | members: new_members}
              new_rooms = Map.put(rooms, room_id, updated_room)

              # Update environment
              new_local_state = Map.put(env_data.local_state, :rooms, new_rooms)
              new_env = %{env_data | local_state: new_local_state}

              # Create effects
              effects = [{:update_environment, new_env}]

              final_effects =
                if msg_sender_address do
                  effects ++ [{:send, msg_sender_address, {:room_joined, room_id, user_id}}]
                else
                  effects
                end

              {:ok, final_effects}
          end
        else
          # Invalid payload
          effects =
            if msg_sender_address do
              [{:send, msg_sender_address, {:error, :invalid_payload}}]
            else
              [:noop]
            end

          {:ok, effects}
        end
      end
    end

    # Leave a chat room
    on_message :leave_room do
      quote do
        room_id = Map.get(msg_payload, :room_id)
        user_id = Map.get(msg_payload, :user_id)

        if room_id && user_id do
          rooms = get_in(env_data.local_state, [:rooms]) || %{}

          case Map.get(rooms, room_id) do
            nil ->
              # Room doesn't exist
              effects =
                if msg_sender_address do
                  [{:send, msg_sender_address, {:error, :room_not_found}}]
                else
                  [:noop]
                end

              {:ok, effects}

            room ->
              current_members = Map.get(room, :members, [])

              if user_id in current_members do
                # Remove user from room
                new_members = List.delete(current_members, user_id)

                # If room is empty, remove it entirely
                new_rooms =
                  if Enum.empty?(new_members) do
                    Map.delete(rooms, room_id)
                  else
                    updated_room = %{room | members: new_members}
                    Map.put(rooms, room_id, updated_room)
                  end

                # Update environment
                new_local_state = Map.put(env_data.local_state, :rooms, new_rooms)
                new_env = %{env_data | local_state: new_local_state}

                # Create effects
                effects = [{:update_environment, new_env}]

                final_effects =
                  if msg_sender_address do
                    effects ++ [{:send, msg_sender_address, {:room_left, room_id, user_id}}]
                  else
                    effects
                  end

                {:ok, final_effects}
              else
                # User not in room
                effects =
                  if msg_sender_address do
                    [{:send, msg_sender_address, {:error, :not_in_room}}]
                  else
                    [:noop]
                  end

                {:ok, effects}
              end
          end
        else
          # Invalid payload
          effects =
            if msg_sender_address do
              [{:send, msg_sender_address, {:error, :invalid_payload}}]
            else
              [:noop]
            end

          {:ok, effects}
        end
      end
    end

    # Send a message to a room
    on_message :send_message do
      quote do
        room_id = Map.get(msg_payload, :room_id)
        message = Map.get(msg_payload, :message)
        priority = Map.get(msg_payload, :priority, :normal)

        if room_id && message do
          rooms = get_in(env_data.local_state, [:rooms]) || %{}

          case Map.get(rooms, room_id) do
            nil ->
              # Room doesn't exist
              effects =
                if msg_sender_address do
                  [{:send, msg_sender_address, {:error, :room_not_found}}]
                else
                  [:noop]
                end

              {:ok, effects}

            room ->
              members = Map.get(room, :members, [])

              # Create message record
              message_id = :crypto.strong_rand_bytes(16) |> Base.encode64()

              message_record = %{
                id: message_id,
                room_id: room_id,
                message: message,
                priority: priority,
                timestamp: DateTime.utc_now(),
                sender: msg_sender_address
              }

              # Add to message history
              message_history = get_in(env_data.local_state, [:message_history]) || []
              # Keep last 100 messages
              new_history = [message_record | Enum.take(message_history, 99)]

              # Update environment
              new_local_state = Map.put(env_data.local_state, :message_history, new_history)
              new_env = %{env_data | local_state: new_local_state}

              # Create effects to broadcast to all members (except sender)
              broadcast_effects =
                members
                |> Enum.reject(&(&1 == msg_sender_address))
                |> Enum.map(fn member ->
                  # In a real implementation, we'd look up member addresses
                  # For now, we'll just create a placeholder effect
                  {:send, {:broadcast_target, member},
                   {:room_message, room_id, message, priority}}
                end)

              # Combine all effects
              effects = [{:update_environment, new_env}] ++ broadcast_effects

              final_effects =
                if msg_sender_address do
                  effects ++ [{:send, msg_sender_address, {:message_delivered, message_id}}]
                else
                  effects
                end

              {:ok, final_effects}
          end
        else
          # Invalid payload
          effects =
            if msg_sender_address do
              [{:send, msg_sender_address, {:error, :invalid_payload}}]
            else
              [:noop]
            end

          {:ok, effects}
        end
      end
    end

    # Set user status (affects message filtering)
    on_message :set_status do
      quote do
        new_status = Map.get(msg_payload, :status)

        if new_status in [:available, :busy, :away] do
          # Update configuration to change filtering behavior
          current_config = config_data.local_state || %{}
          new_config_state = Map.put(current_config, :status, new_status)
          new_config = %{config_data | local_state: new_config_state}

          # Also update user status in environment
          user_status = get_in(env_data.local_state, [:user_status]) || %{}
          # Use sender address as user identifier
          user_key = msg_sender_address || :self
          new_user_status = Map.put(user_status, user_key, new_status)

          new_local_state = Map.put(env_data.local_state, :user_status, new_user_status)
          new_env = %{env_data | local_state: new_local_state}

          # Create a custom filter based on the new status
          new_filter =
            case new_status do
              :available ->
                fn _msg, _config, _env -> true end

              :busy ->
                fn msg, config, _env ->
                  {tag, payload} =
                    case msg do
                      {tag, payload} -> {tag, payload}
                      tag when is_atom(tag) -> {tag, %{}}
                      _ -> {:unknown, %{}}
                    end

                  priority_filtering = get_in(config, [:local_state, :priority_filtering]) || true

                  if priority_filtering do
                    case tag do
                      tag when tag in [:join_room, :leave_room, :set_status, :get_status] ->
                        true

                      :send_message ->
                        Map.get(payload, :priority, :normal) == :urgent

                      :private_message ->
                        Map.get(payload, :priority, :normal) == :urgent

                      :broadcast ->
                        false

                      tag
                      when tag in [:message_delivered, :status_response, :room_joined, :room_left] ->
                        true

                      _ ->
                        false
                    end
                  else
                    true
                  end
                end

              :away ->
                fn msg, _config, _env ->
                  {tag, payload} =
                    case msg do
                      {tag, payload} -> {tag, payload}
                      tag when is_atom(tag) -> {tag, %{}}
                      _ -> {:unknown, %{}}
                    end

                  case tag do
                    tag when tag in [:set_status, :get_status] -> true
                    :private_message -> Map.get(payload, :priority, :normal) == :urgent
                    _ -> false
                  end
                end
            end

          # Create effects: update environment and change mailbox filter
          effects = [
            {:update_environment, new_env},
            {:mfilter, new_filter}
          ]

          final_effects =
            if msg_sender_address do
              effects ++ [{:send, msg_sender_address, {:status_response, user_key, new_status}}]
            else
              effects
            end

          {:ok, final_effects}
        else
          # Invalid status
          effects =
            if msg_sender_address do
              [{:send, msg_sender_address, {:error, :invalid_status}}]
            else
              [:noop]
            end

          {:ok, effects}
        end
      end
    end

    # Get user status
    on_message :get_status do
      quote do
        user_id = Map.get(msg_payload, :user_id)
        user_status = get_in(env_data.local_state, [:user_status]) || %{}

        status =
          if user_id do
            Map.get(user_status, user_id, :unknown)
          else
            # Get own status
            current_status = get_in(config_data.local_state, [:status]) || :available
            current_status
          end

        effects =
          if msg_sender_address do
            [{:send, msg_sender_address, {:status_response, user_id || :self, status}}]
          else
            [:noop]
          end

        {:ok, effects}
      end
    end
  end
end
