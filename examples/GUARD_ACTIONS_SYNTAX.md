# Engine Guard Actions Syntax Guide

This guide explains how to write engines with behaviors that require guard actions in the EngineSystem framework.

## Overview

Guard actions are conditional checks that determine whether a message should be processed and how it should be handled. They provide a way to implement security, validation, rate limiting, and other conditional logic in your engine behaviors.

## Available Syntax Patterns

### 1. Function-Based Message Handlers with Guard Logic

**Recommended approach** - Uses the proven `on_message` syntax with explicit guard conditions:

```elixir
behaviour do
  on_message :operation, %{param: value, user: user}, config, env, sender do
    cond do
      # Guard condition 1
      not is_authenticated?(user, env) ->
        {:ok, [{:send, sender, {:error, :not_authenticated}}]}
      
      # Guard condition 2
      not has_permission?(user, :operation) ->
        {:ok, [{:send, sender, {:error, :insufficient_permissions}}]}
      
      # All guards passed
      true ->
        # Process the operation
        {:ok, [{:send, sender, {:success, result}}]}
    end
  end
end
```

### 2. Elixir `with` Expressions for Sequential Guards

Great for chaining multiple guard checks with early exit:

```elixir
on_message :read_document, %{id: doc_id, user: user}, config, env, sender do
  with {:auth, true} <- {:auth, is_authenticated?(user, env)},
       {:doc, document} when document != nil <- {:doc, get_document(doc_id, env)},
       {:permission, true} <- {:permission, can_read?(user, document)} do
    
    # All guards passed - process request
    {:ok, [{:send, sender, {:document_content, document.content}}]}
  else
    {:auth, false} -> {:ok, [{:send, sender, {:error, :not_authenticated}}]}
    {:doc, nil} -> {:ok, [{:send, sender, {:error, :document_not_found}}]}
    {:permission, false} -> {:ok, [{:send, sender, {:error, :access_denied}}]}
  end
end
```

### 3. Case Expressions for Complex Guard Logic

Useful when you need to evaluate guards that return different types of results:

```elixir
on_message :api_request, %{client_id: id, ip: ip, data: data}, config, env, sender do
  case evaluate_request_guards(id, ip, config, env) do
    {:allow, updated_env} ->
      response = process_request(data)
      {:ok, [
        {:update_environment, updated_env},
        {:send, sender, {:response, response}}
      ]}
    
    {:rate_limited, retry_after} ->
      {:ok, [{:send, sender, {:rate_limited, retry_after}}]}
    
    {:blocked, reason} ->
      {:ok, [{:send, sender, {:blocked, reason}}]}
  end
end
```

### 4. Custom Guard Helper Functions

Create reusable guard functions for complex logic:

```elixir
defp evaluate_request_guards(client_id, ip, config, env) do
  cond do
    ip in config.blacklisted_ips ->
      {:blocked, "IP blacklisted"}
    
    rate_limit_exceeded?(client_id, config, env) ->
      {:rate_limited, 60}
    
    true ->
      {:allow, update_rate_limits(client_id, env)}
  end
end

defp is_authenticated?(user, env) do
  user != nil and 
  user.session_token != nil and
  Map.has_key?(env.active_sessions, user.id)
end

defp has_permission?(user, action) do
  case {user.role, action} do
    {:admin, _} -> true
    {:editor, action} when action in [:read, :write] -> true
    {:viewer, :read} -> true
    _ -> false
  end
end
```

## Common Guard Patterns

### Authentication Guards

```elixir
# Simple authentication check
defp is_authenticated?(user, env) do
  user != nil and user.session_token != nil and
  Map.has_key?(env.active_sessions, user.id)
end

# Role-based authorization
defp has_role?(user, required_role) do
  user.role == required_role
end

# Permission-based authorization
defp has_permission?(user, resource, action) do
  user.role == :admin or
  (resource.owner_id == user.id and action in [:read, :update]) or
  (user.role == :editor and action in [:read, :create, :update])
end
```

### Validation Guards

```elixir
# Input validation
defp valid_input?(data, config) do
  byte_size(data.content) <= config.max_size and
  data.format in config.allowed_formats
end

# Business rule validation
defp meets_business_rules?(operation, env) do
  operation.amount <= env.daily_limit and
  operation.timestamp >= env.business_hours_start
end
```

### Rate Limiting Guards

```elixir
defp rate_limit_check(client_id, config, env) do
  counts = Map.get(env.rate_limits, client_id, %{count: 0, reset_time: 0})
  now = System.system_time(:second)
  
  if now >= counts.reset_time do
    # Reset window
    if 1 <= config.max_requests do
      {:allow, update_rate_limit(client_id, now, env)}
    else
      {:denied, config.window_size}
    end
  else
    # Within window
    if counts.count < config.max_requests do
      {:allow, increment_rate_limit(client_id, env)}
    else
      {:denied, counts.reset_time - now}
    end
  end
end
```

## Advanced Patterns

### Sequential Guard Evaluation

For when you need to evaluate guards in a specific order and stop at the first failure:

```elixir
defp guard_check_sequence(checks) do
  Enum.reduce_while(checks, {:ok, nil}, fn
    {:authenticated, check_fn}, acc ->
      if check_fn.() do
        {:cont, acc}
      else
        {:halt, {:error, "Not authenticated"}}
      end
    
    {:document_exists, check_fn}, acc ->
      case check_fn.() do
        nil -> {:halt, {:error, "Document not found"}}
        doc -> {:cont, {:ok, doc}}
      end
    
    {:permission, check_fn}, {_, doc} ->
      if check_fn.(doc) do
        {:cont, {:ok, doc}}
      else
        {:halt, {:error, "Insufficient permissions"}}
      end
  end)
end

# Usage:
case guard_check_sequence([
  {:authenticated, fn -> is_authenticated?(user, env) end},
  {:document_exists, fn -> get_document(doc_id, env) end},
  {:permission, fn doc -> can_modify?(user, doc) end}
]) do
  {:ok, document} -> # All guards passed
  {:error, reason} -> # A guard failed
end
```

### Conditional Guard Chains

For complex conditional logic:

```elixir
on_message :complex_operation, payload, config, env, sender do
  result = 
    if payload.urgent do
      # Different guards for urgent operations
      with :ok <- check_emergency_auth(payload.user),
           :ok <- validate_urgent_request(payload),
           {:ok, resource} <- acquire_emergency_resource() do
        process_urgent_operation(payload, resource)
      end
    else
      # Standard guards for normal operations
      with :ok <- check_standard_auth(payload.user, env),
           :ok <- check_rate_limits(payload.user, env),
           :ok <- validate_standard_request(payload),
           {:ok, resource} <- acquire_standard_resource() do
        process_standard_operation(payload, resource)
      end
    end
  
  case result do
    {:ok, response} -> {:ok, [{:send, sender, {:success, response}}]}
    {:error, reason} -> {:ok, [{:send, sender, {:error, reason}}]}
  end
end
```

## Best Practices

1. **Keep guards simple and focused** - Each guard should check one specific condition
2. **Use descriptive names** - Make it clear what each guard is checking
3. **Fail fast** - Check the most likely-to-fail conditions first
4. **Provide meaningful error messages** - Help users understand why their request was denied
5. **Document complex guard logic** - Explain the business rules being enforced
6. **Test edge cases** - Ensure guards work correctly for boundary conditions
7. **Consider performance** - Expensive checks should be done last
8. **Use helper functions** - Extract reusable guard logic into private functions

## Example Usage

See `examples/guard_actions_simple_example.ex` for complete working examples that demonstrate:

- **SecureDocumentEngine**: Authentication, authorization, and validation guards
- **RateLimitedService**: IP filtering and rate limiting guards

Both examples use the proven function-based syntax and demonstrate different patterns for implementing guard actions in your engines.

## Running the Examples

```bash
# Start an Elixir session
iex -S mix

# Load the example
iex> c "examples/guard_actions_simple_example.ex"

# Run the demonstrations
iex> GuardActionsSimpleExample.run_all_demos()
```

This will show you guard actions in practice, including successful operations and guard failures. 