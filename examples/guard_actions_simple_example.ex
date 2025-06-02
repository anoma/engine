defmodule GuardActionsSimpleExample do
  @moduledoc """
  A simple, working example demonstrating how to write engines with behaviors
  that require guard actions in the EngineSystem framework.

  This example uses the proven function-based syntax with built-in guard conditions
  rather than the more complex DSL patterns.
  """

  use EngineSystem

  # ============================================================================
  # EXAMPLE 1: Secure Document Engine with Guard Conditions
  # ============================================================================

  defengine SecureDocumentEngine do
    version("1.0.0")
    mode(:process)

    config do
      %{
        max_document_size: 1_000_000,  # 1MB
        allowed_roles: [:admin, :editor, :viewer],
        security_level: :high
      }
    end

    env do
      %{
        documents: %{},
        access_log: [],
        active_sessions: %{}
      }
    end

    interface do
      # Document operations
      message(:create_document, [:title, :content, :user])
      message(:read_document, [:id, :user])
      message(:update_document, [:id, :content, :user])
      message(:delete_document, [:id, :user])

      # User operations
      message(:authenticate, [:username, :password])

      # Response messages
      message(:document_created, [:id])
      message(:document_content, [:content])
      message(:operation_success, [:action])
      message(:access_denied, [:reason])
      message(:authenticated, [:user_id, :session_token])
      message(:authentication_failed, [])
    end

    behaviour do
      # Authentication handler with guard actions
      on_message :authenticate, %{username: username, password: password}, _config, env, sender do
        # Guard action: Check if credentials are valid
        user = authenticate_user(username, password)

        if user != nil do
          # Guard passed: Create session
          session_token = generate_session_token()
          user_with_session = Map.put(user, :session_token, session_token)

          new_sessions = Map.put(env.active_sessions, user.id, user_with_session)
          new_env = %{env | active_sessions: new_sessions}

          {:ok, [
            {:update_environment, new_env},
            {:send, sender, {:authenticated, user.id, session_token}}
          ]}
        else
          # Guard failed: Authentication denied
          {:ok, [{:send, sender, {:authentication_failed, %{}}}]}
        end
      end

      # Document creation with multiple guard conditions
      on_message :create_document, %{title: title, content: content, user: user}, config, env, sender do
        cond do
          # Guard 1: Check authentication
          not is_authenticated?(user, env) ->
            {:ok, [{:send, sender, {:access_denied, "Not authenticated"}}]}

          # Guard 2: Check permission for creation
          not has_create_permission?(user) ->
            {:ok, [{:send, sender, {:access_denied, "Insufficient permissions"}}]}

          # Guard 3: Check document size limit
          byte_size(content) > config.max_document_size ->
            {:ok, [{:send, sender, {:access_denied, "Document too large"}}]}

          # All guards passed: Create document
          true ->
            doc_id = generate_document_id()
            new_document = %{
              id: doc_id,
              title: title,
              content: content,
              owner_id: user.id,
              created_at: DateTime.utc_now()
            }

            new_documents = Map.put(env.documents, doc_id, new_document)
            log_entry = create_log_entry(:create_document, user.id, doc_id)
            new_log = [log_entry | env.access_log]

            new_env = %{env | documents: new_documents, access_log: new_log}

            {:ok, [
              {:update_environment, new_env},
              {:send, sender, {:document_created, doc_id}}
            ]}
        end
      end

      # Document reading with guard conditions
      on_message :read_document, %{id: doc_id, user: user}, _config, env, sender do
        with {:auth, true} <- {:auth, is_authenticated?(user, env)},
             {:doc_exists, document} when document != nil <- {:doc_exists, Map.get(env.documents, doc_id)},
             {:permission, true} <- {:permission, has_read_permission?(user, document)} do

          # All guards passed: Return document content
          log_entry = create_log_entry(:read_document, user.id, doc_id)
          new_log = [log_entry | env.access_log]
          new_env = %{env | access_log: new_log}

          {:ok, [
            {:update_environment, new_env},
            {:send, sender, {:document_content, document.content}}
          ]}
        else
          {:auth, false} ->
            {:ok, [{:send, sender, {:access_denied, "Not authenticated"}}]}

          {:doc_exists, nil} ->
            {:ok, [{:send, sender, {:access_denied, "Document not found"}}]}

          {:permission, false} ->
            {:ok, [{:send, sender, {:access_denied, "Insufficient permissions"}}]}
        end
      end

      # Document update with cascading guard checks
      on_message :update_document, %{id: doc_id, content: new_content, user: user}, config, env, sender do
        # Sequential guard evaluation
        case guard_check_sequence([
          {:authenticated, fn -> is_authenticated?(user, env) end},
          {:document_exists, fn -> Map.get(env.documents, doc_id) end},
          {:size_valid, fn -> byte_size(new_content) <= config.max_document_size end},
          {:permission, fn doc -> has_update_permission?(user, doc) end}
        ]) do
          {:ok, document} ->
            # All guards passed: Update document
            updated_document = %{document |
              content: new_content,
              updated_at: DateTime.utc_now()
            }

            new_documents = Map.put(env.documents, doc_id, updated_document)
            log_entry = create_log_entry(:update_document, user.id, doc_id)
            new_log = [log_entry | env.access_log]

            new_env = %{env | documents: new_documents, access_log: new_log}

            {:ok, [
              {:update_environment, new_env},
              {:send, sender, {:operation_success, :update}}
            ]}

          {:error, reason} ->
            {:ok, [{:send, sender, {:access_denied, reason}}]}
        end
      end

      # Document deletion with role-based guards
      on_message :delete_document, %{id: doc_id, user: user}, _config, env, sender do
        document = Map.get(env.documents, doc_id)

        # Multiple guard conditions with short-circuit evaluation
        cond do
          not is_authenticated?(user, env) ->
            {:ok, [{:send, sender, {:access_denied, "Not authenticated"}}]}

          document == nil ->
            {:ok, [{:send, sender, {:access_denied, "Document not found"}}]}

          not is_admin?(user) and document.owner_id != user.id ->
            {:ok, [{:send, sender, {:access_denied, "Can only delete own documents"}}]}

          true ->
            # Guards passed: Delete document
            new_documents = Map.delete(env.documents, doc_id)
            log_entry = create_log_entry(:delete_document, user.id, doc_id)
            new_log = [log_entry | env.access_log]

            new_env = %{env | documents: new_documents, access_log: new_log}

            {:ok, [
              {:update_environment, new_env},
              {:send, sender, {:operation_success, :delete}}
            ]}
        end
      end
    end

    # ========================================================================
    # GUARD HELPER FUNCTIONS
    # ========================================================================

    # Authentication guard
    defp is_authenticated?(user, env) do
      user != nil and
      user.id != nil and
      user.session_token != nil and
      Map.has_key?(env.active_sessions, user.id)
    end

    # Permission guards
    defp has_create_permission?(user) do
      user.role in [:admin, :editor]
    end

    defp has_read_permission?(user, document) do
      user.role == :admin or
      document.owner_id == user.id or
      user.role in [:editor, :viewer]
    end

    defp has_update_permission?(user, document) do
      user.role == :admin or document.owner_id == user.id
    end

    defp is_admin?(user) do
      user.role == :admin
    end

    # Utility functions
    defp authenticate_user(username, password) do
      case {username, password} do
        {"admin", "admin123"} -> %{id: 1, username: "admin", role: :admin}
        {"editor", "edit123"} -> %{id: 2, username: "editor", role: :editor}
        {"viewer", "view123"} -> %{id: 3, username: "viewer", role: :viewer}
        _ -> nil
      end
    end

    defp generate_session_token do
      "session_#{:rand.uniform(1_000_000)}"
    end

    defp generate_document_id do
      "doc_#{:rand.uniform(1_000_000)}"
    end

    defp create_log_entry(action, user_id, doc_id) do
      %{
        action: action,
        user_id: user_id,
        document_id: doc_id,
        timestamp: DateTime.utc_now()
      }
    end

    # Sequential guard checker that stops at first failure
    defp guard_check_sequence(checks) do
      Enum.reduce_while(checks, {:ok, nil}, fn
        {:authenticated, check_fn}, acc ->
          if check_fn.() do
            {:cont, acc}
          else
            {:halt, {:error, "Not authenticated"}}
          end

        {:document_exists, check_fn}, _acc ->
          case check_fn.() do
            nil -> {:halt, {:error, "Document not found"}}
            doc -> {:cont, {:ok, doc}}
          end

        {:size_valid, check_fn}, acc ->
          if check_fn.() do
            {:cont, acc}
          else
            {:halt, {:error, "Document too large"}}
          end

        {:permission, check_fn}, {_, doc} ->
          if check_fn.(doc) do
            {:cont, {:ok, doc}}
          else
            {:halt, {:error, "Insufficient permissions"}}
          end
      end)
    end
  end

  # ============================================================================
  # EXAMPLE 2: Rate Limited Service with Time-based Guards
  # ============================================================================

  defengine RateLimitedService do
    version("1.0.0")
    mode(:process)

    config do
      %{
        max_requests_per_minute: 10,
        max_requests_per_hour: 100,
        blacklisted_ips: ["192.168.1.100"]
      }
    end

    env do
      %{
        request_counts: %{},
        total_requests: 0
      }
    end

    interface do
      message(:api_request, [:client_id, :ip_address, :request_data])
      message(:request_processed, [:response])
      message(:rate_limited, [:retry_after])
      message(:request_blocked, [:reason])
    end

    behaviour do
      on_message :api_request, %{client_id: client_id, ip_address: ip, request_data: data}, config, env, sender do
        now = System.system_time(:second)

        # Guard sequence for rate limiting
        case evaluate_rate_limit_guards(client_id, ip, now, config, env) do
          {:allow, updated_env} ->
            # Process the request
            response = process_request(data)

            {:ok, [
              {:update_environment, updated_env},
              {:send, sender, {:request_processed, response}}
            ]}

          {:rate_limit, retry_after} ->
            {:ok, [{:send, sender, {:rate_limited, retry_after}}]}

          {:blocked, reason} ->
            {:ok, [{:send, sender, {:request_blocked, reason}}]}
        end
      end
    end

    # Rate limiting guard logic
    defp evaluate_rate_limit_guards(client_id, ip, now, config, env) do
      cond do
        # Guard 1: Check IP blacklist
        ip in config.blacklisted_ips ->
          {:blocked, "IP blacklisted"}

        # Guard 2: Check rate limits
        rate_limit_exceeded?(client_id, now, config, env) ->
          {:rate_limit, 60}  # Retry after 60 seconds

        # Guards passed: Allow request
        true ->
          updated_env = update_request_counts(client_id, now, env)
          {:allow, updated_env}
      end
    end

    defp rate_limit_exceeded?(client_id, now, config, env) do
      counts = Map.get(env.request_counts, client_id, %{minute: 0, hour: 0, last_minute: now, last_hour: now})

      minute_start = now - rem(now, 60)
      hour_start = now - rem(now, 3600)

      # Reset counters if time windows have passed
      {minute_count, hour_count} =
        if counts.last_minute < minute_start do
          {0, if(counts.last_hour < hour_start, do: 0, else: counts.hour)}
        else
          {counts.minute, counts.hour}
        end

      minute_count >= config.max_requests_per_minute or
      hour_count >= config.max_requests_per_hour
    end

    defp update_request_counts(client_id, now, env) do
      minute_start = now - rem(now, 60)
      hour_start = now - rem(now, 3600)

      counts = Map.get(env.request_counts, client_id, %{minute: 0, hour: 0, last_minute: now, last_hour: now})

      # Update counters
      {new_minute, new_hour} =
        if counts.last_minute < minute_start do
          {1, if(counts.last_hour < hour_start, do: 1, else: counts.hour + 1)}
        else
          {counts.minute + 1, counts.hour + 1}
        end

      updated_counts = %{
        minute: new_minute,
        hour: new_hour,
        last_minute: now,
        last_hour: now
      }

      new_request_counts = Map.put(env.request_counts, client_id, updated_counts)
      %{env |
        request_counts: new_request_counts,
        total_requests: env.total_requests + 1
      }
    end

    defp process_request(data) do
      # Simulate request processing
      %{
        status: :success,
        data: data,
        processed_at: DateTime.utc_now()
      }
    end
  end

  # ============================================================================
  # DEMONSTRATION FUNCTIONS
  # ============================================================================

  @doc """
  Demonstrates the Secure Document Engine with guard actions.
  """
  def demo_secure_documents do
    IO.puts("🚀 Starting Secure Document Engine Demo")

    # Start the system
    {:ok, _} = start()

    # Spawn the document engine
    {:ok, doc_engine} = spawn_engine(SecureDocumentEngine)

    IO.puts("🔐 Testing authentication...")
    send_message(doc_engine, {:authenticate, %{username: "admin", password: "admin123"}})

    # Create a demo user session
    admin_user = %{id: 1, username: "admin", role: :admin, session_token: "session_123"}
    viewer_user = %{id: 3, username: "viewer", role: :viewer, session_token: "session_456"}

    IO.puts("📝 Testing document creation with admin user...")
    send_message(doc_engine, {:create_document, %{
      title: "Security Policy",
      content: "This document contains security guidelines...",
      user: admin_user
    }})

    IO.puts("🔒 Testing document creation with viewer user (should fail)...")
    send_message(doc_engine, {:create_document, %{
      title: "Unauthorized Document",
      content: "This should not be created...",
      user: viewer_user
    }})

    IO.puts("✅ Secure Document Engine demo completed!")
  end

  @doc """
  Demonstrates the Rate Limited Service.
  """
  def demo_rate_limiting do
    IO.puts("🚀 Starting Rate Limited Service Demo")

    # Start the system
    {:ok, _} = start()

    # Spawn the service
    {:ok, service} = spawn_engine(RateLimitedService)

    IO.puts("✅ Testing normal API request...")
    send_message(service, {:api_request, %{
      client_id: "client_123",
      ip_address: "192.168.1.50",
      request_data: %{action: "get_data"}
    }})

    IO.puts("🚫 Testing request from blacklisted IP...")
    send_message(service, {:api_request, %{
      client_id: "client_456",
      ip_address: "192.168.1.100",  # Blacklisted
      request_data: %{action: "get_sensitive_data"}
    }})

    IO.puts("✅ Rate Limited Service demo completed!")
  end

  @doc """
  Runs all demonstrations.
  """
  def run_all_demos do
    demo_secure_documents()
    IO.puts("")
    demo_rate_limiting()
  end
end
