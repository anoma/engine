defmodule EngineSystem.Engine.DSL.BehaviorBuilder do
  @moduledoc """
  I handle the enhanced behavior DSL for engine definitions.

  I manage:
  - Behavior rule definitions with complex pattern matching
  - Message handler definitions with guard support
  - Reusable guard definitions
  - Behavior validation

  ## Examples

  ```elixir
  behaviour do
    # Define a reusable guard
    guard :has_permission, %{user: user} do
      user.role in [:admin, :editor]
    end

    # Define a message handler with pattern matching
    on_message :update_document, %{id: id, content: content, user: user} do
      # Match with guard
      when_guard :has_permission(%{user: user}) do
        quote do
          # Handler implementation
          new_env = update_document(env_data, id, content)
          {:ok, [{:update_environment, new_env}]}
        end
      end

      # Fallback case
      otherwise do
        quote do
          {:ok, [{:send, msg_sender_address, {:error, :permission_denied}}]}
        end
      end
    end
  end
  ```
  """

  # Suppress warnings for functions used in macro-generated code
  @compile {:nowarn_unused_function, [{:guard_arity, 1}]}

  @doc """
  I define the behavior rules for the engine with enhanced guard support.

  ## Parameters

  - `block` - Block containing behavior rule definitions and guards

  ## Returns

  Quoted AST for behavior definition

  ## Example

  ```elixir
  behaviour do
    # Define guards and message handlers here
    guard :is_admin, %{user: user} do
      user.role == :admin
    end

    on_message :delete_record do
      when_guard :is_admin do
        quote do
          # Implementation for admins
        end
      end
    end
  end
  ```
  """
  defmacro behaviour(do: block) do
    quote do
      # Initialize state for guards and patterns
      Module.put_attribute(__MODULE__, :guard_registry, %{})
      Module.put_attribute(__MODULE__, :current_behaviour_rules, [])
      Module.put_attribute(__MODULE__, :current_message_patterns, %{})
      Module.put_attribute(__MODULE__, :pattern_priority_counter, 0)

      unquote(block)

      # Finalize behavior with compiled guards and patterns
      finalize_behavior_with_guards()
    end
  end

  @doc """
  I define a reusable guard that can be referenced in message handlers.

  ## Parameters

  - `guard_name` - Name of the guard
  - `payload_pattern` - Optional pattern to match against message payload
  - `block` - Guard expression block

  ## Returns

  Quoted AST for guard definition

  ## Examples

  ```elixir
  # Simple guard with no pattern matching
  guard :allow_all do
    true
  end

  # Guard with pattern matching
  guard :valid_user, %{user_id: id} do
    id > 0 and is_integer(id)
  end

  # Complex guard with conditions
  guard :has_permission, %{user: user, resource: resource} do
    user.role in [:admin, :owner] or resource.owner_id == user.id
  end
  ```
  """
  defmacro guard(guard_name, payload_pattern \\ quote(do: _), do: guard_expr) do
    # Calculate arity at macro expansion time
    arity = guard_arity(payload_pattern)

    quote do
      guard_registry = Module.get_attribute(__MODULE__, :guard_registry)

      compiled_guard = %{
        name: unquote(guard_name),
        payload_pattern: unquote(Macro.escape(payload_pattern)),
        expression: unquote(Macro.escape(guard_expr)),
        arity: unquote(arity)
      }

      updated_registry = Map.put(guard_registry, unquote(guard_name), compiled_guard)
      Module.put_attribute(__MODULE__, :guard_registry, updated_registry)
    end
  end

  @doc """
  I define a message handler with enhanced pattern matching support.

  ## Parameters

  - `tag` - Message tag to handle
  - `payload_pattern` - Optional pattern to match against message payload
  - `block` - Handler implementation block with when clauses

  ## Returns

  Quoted AST for message handler definition

  ## Examples

  ```elixir
  # Simple message with no pattern matching
  on_message :ping do
    when_guard true do
      quote do
        {:ok, [{:send, msg_sender_address, :pong}]}
      end
    end
  end

  # Message with pattern matching
  on_message :create_user, %{name: name, email: email} do
    when_guard :valid_email(%{email: email}) do
      quote do
        user = create_user(name, email)
        {:ok, [{:send, msg_sender_address, {:user_created, user.id}}]}
      end
    end

    otherwise do
      quote do
        {:ok, [{:send, msg_sender_address, {:error, :invalid_email}}]}
      end
    end
  end
  ```
  """
  defmacro on_message(tag, payload_pattern \\ quote(do: msg), do: block) do
    quote do
      start_message_pattern_collection(unquote(tag), unquote(Macro.escape(payload_pattern)))
      unquote(block)
      finalize_message_patterns(unquote(tag))
    end
  end

  @doc """
  I define a message handler with function-based syntax for compile-time validation.

  This is the enhanced version that creates actual function definitions instead of
  using quote blocks, providing compile-time validation of business logic.

  ## Parameters

  - `tag` - Message tag to handle
  - `msg_payload` - Variable name for the message payload
  - `config` - Variable name for the configuration
  - `env` - Variable name for the environment
  - `sender` - Variable name for the message sender
  - `block` - Handler implementation block (raw Elixir code, not quoted)

  ## Returns

  Quoted AST for function-based handler definition

  ## Examples

  ```elixir
  # Simple message handler with compile-time validation
  on_message :tick, _msg_payload, config, env, _sender do
    count = env.count
    max = config.max_value  # ← Will catch undefined variables at compile time!
    new_count = if count >= max, do: 0, else: count + 1
    new_env = %{env | count: new_count}
    {:ok, [{:update_environment, new_env}]}
  end

  # Handler with payload pattern matching
  on_message :add, %{a: a, b: b}, config, env, sender do
    if a > config.max_value or b > config.max_value do
      {:ok, [{:send, sender, {:error, :value_too_large}}]}
    else
      result = a + b
      {:ok, [{:send, sender, {:result, result}}]}
    end
  end
  ```
  """
  defmacro on_message(tag, msg_payload, config, env, sender, do: block) do
    handler_name = :"__handle_#{tag}__"

    quote do
      # Generate actual function with compile-time validation
      def unquote(handler_name)(
            unquote(msg_payload),
            unquote(config),
            unquote(env),
            unquote(sender)
          ) do
        unquote(block)
      end

      # Register this handler in the behavior rules
      current_rules = Module.get_attribute(__MODULE__, :current_behaviour_rules, [])
      new_rule = {unquote(tag), {:function_handler, __MODULE__, unquote(handler_name)}}
      Module.put_attribute(__MODULE__, :current_behaviour_rules, [new_rule | current_rules])
    end
  end

  @doc """
  I define a guarded pattern within a message handler with improved syntax.

  Supports:
  - Simple atoms: `when_guard :has_read_access`
  - Function calls: `when_guard :valid_key(%{key: key})`
  - Complex expressions: `when_guard :has_read_access and :valid_key(%{key: key})`
  - With-like syntax for data-returning guards

  ## Parameters

  - `guard_expr` - Guard expression using atoms and function calls
  - `block` - Handler body for this pattern

  ## Returns

  Quoted AST for pattern definition

  ## Examples

  ```elixir
  # Simple guard reference
  when_guard :is_admin do
    quote do
      # Admin-only code here
      {:ok, [{:update_environment, new_env}]}
    end
  end

  # Pattern-matched guard
  when_guard :has_permission(%{resource_id: id, action: :delete}) do
    quote do
      # Delete permission implementation
      {:ok, [{:send, msg_sender_address, :resource_deleted}]}
    end
  end

  # Complex expression with multiple guards
  when_guard :is_authenticated and :has_role(%{role: :editor}) do
    quote do
      # Implementation for authenticated editors
      {:ok, [{:noop}]}
    end
  end
  ```
  """
  defmacro when_guard(guard_expr, do: body) do
    # Compile the guard syntax at macro expansion time, not at runtime
    compiled_guard_expr = compile_guard_syntax(guard_expr)

    quote do
      add_pattern_with_guard(
        unquote(Macro.escape(compiled_guard_expr)),
        unquote(Macro.escape(body))
      )
    end
  end

  @doc """
  I define a with-like pattern for guards that return data.

  ## Parameters

  - `bindings` - List of guard bindings with arrows
  - `final_guard` - Final boolean guard (optional)
  - `block` - Handler body

  ## Returns

  Quoted AST for with-pattern definition

  ## Examples

  ```elixir
  # Binding a value from a guard
  with_guard user <- :find_user(%{user_id: id}) do
    quote do
      # Can use 'user' variable here
      {:ok, [{:send, msg_sender_address, {:user_info, user}}]}
    end
  end

  # Using result with conditions
  with_guard token <- :parse_token(%{auth: auth_header}) do
    quote do
      case validate_token(token) do
        :ok -> {:ok, [{:update_environment, new_env}]}
        :error -> {:ok, [{:send, msg_sender_address, {:error, :invalid_token}}]}
      end
    end
  end

  # Multiple bindings (future enhancement)
  # with_guard user <- :find_user(%{id: id}),
  #            permissions <- :get_permissions(%{user: user}) do
  #   # Use both user and permissions here
  # end
  ```
  """
  defmacro with_guard(bindings, do: body) do
    # Compile the with-guard syntax at macro expansion time
    compiled_with_expr = compile_with_guard_syntax(bindings)

    quote do
      add_pattern_with_guard(
        unquote(Macro.escape(compiled_with_expr)),
        unquote(Macro.escape(body))
      )
    end
  end

  @doc """
  I define a fallback pattern for a message handler.

  ## Parameters

  - `block` - Fallback handler body

  ## Returns

  Quoted AST for otherwise pattern

  ## Example

  ```elixir
  on_message :process_payment, %{amount: amount, card: card} do
    when_guard :valid_payment(%{amount: amount, card: card}) do
      quote do
        # Process valid payment
        {:ok, [{:send, msg_sender_address, :payment_processed}]}
      end
    end

    otherwise do
      quote do
        # Handle invalid payment
        {:ok, [{:send, msg_sender_address, {:error, :invalid_payment}}]}
      end
    end
  end
  ```
  """
  defmacro otherwise(do: body) do
    quote do
      add_otherwise_pattern(unquote(Macro.escape(body)))
    end
  end

  @doc """
  I start collecting patterns for a specific message type.
  """
  defmacro start_message_pattern_collection(msg_type, payload_pattern) do
    quote do
      current_patterns = Module.get_attribute(__MODULE__, :current_message_patterns)

      Module.put_attribute(
        __MODULE__,
        :current_message_patterns,
        Map.put(current_patterns, unquote(msg_type), %{
          payload_pattern: unquote(payload_pattern),
          patterns: [],
          current_priority: 0
        })
      )
    end
  end

  @doc """
  I add a guarded pattern to the current message being defined.
  """
  defmacro add_pattern_with_guard(guard_expr, body) do
    quote do
      current_patterns = Module.get_attribute(__MODULE__, :current_message_patterns)
      counter = Module.get_attribute(__MODULE__, :pattern_priority_counter)

      # Find the message type being currently defined
      current_msg_type =
        __MODULE__.get_current_message_type(current_patterns)

      if current_msg_type do
        msg_data = Map.get(current_patterns, current_msg_type)
        new_priority = counter + 1

        new_pattern = %{
          guard_ast: unquote(guard_expr),
          handler_ast: unquote(body),
          priority: new_priority
        }

        updated_patterns = msg_data.patterns ++ [new_pattern]
        updated_msg_data = %{msg_data | patterns: updated_patterns}
        updated_current = Map.put(current_patterns, current_msg_type, updated_msg_data)

        Module.put_attribute(__MODULE__, :current_message_patterns, updated_current)
        Module.put_attribute(__MODULE__, :pattern_priority_counter, new_priority)
      end
    end
  end

  @doc """
  I add an otherwise (fallback) pattern to the current message.
  """
  defmacro add_otherwise_pattern(body) do
    quote do
      current_patterns = Module.get_attribute(__MODULE__, :current_message_patterns)

      current_msg_type =
        __MODULE__.get_current_message_type(current_patterns)

      if current_msg_type do
        msg_data = Map.get(current_patterns, current_msg_type)

        otherwise_pattern = %{
          guard_ast: :otherwise,
          handler_ast: unquote(body),
          # Always last
          priority: 999
        }

        updated_patterns = msg_data.patterns ++ [otherwise_pattern]
        updated_msg_data = %{msg_data | patterns: updated_patterns}
        updated_current = Map.put(current_patterns, current_msg_type, updated_msg_data)

        Module.put_attribute(__MODULE__, :current_message_patterns, updated_current)
      end
    end
  end

  @doc """
  I finalize patterns for a specific message type.
  """
  defmacro finalize_message_patterns(_msg_type) do
    quote do
      # This will be called after each on_message block is processed
      # Pattern compilation happens in finalize_behavior_with_guards
      :ok
    end
  end

  @doc """
  I finalize all behavior patterns and guards into behavior rules.
  """
  defmacro finalize_behavior_with_guards do
    quote do
      guard_registry = Module.get_attribute(__MODULE__, :guard_registry)
      message_patterns = Module.get_attribute(__MODULE__, :current_message_patterns)
      function_rules = Module.get_attribute(__MODULE__, :current_behaviour_rules, [])

      # Compile complex patterns into behavior rules
      complex_pattern_rules = compile_patterns_to_rules(message_patterns, guard_registry)

      # Merge function handlers and complex patterns
      # Function handlers take precedence over complex patterns for the same tag
      all_rules = merge_behavior_rules(function_rules, complex_pattern_rules)

      # Update engine spec
      spec_data = Module.get_attribute(__MODULE__, :engine_spec_data)
      updated_spec = %{spec_data | behaviour_rules: all_rules}
      Module.put_attribute(__MODULE__, :engine_spec_data, updated_spec)

      # Store guard registry for compilation
      Module.put_attribute(__MODULE__, :compiled_guard_registry, guard_registry)

      # Cleanup
      Module.delete_attribute(__MODULE__, :current_behaviour_rules)
      Module.delete_attribute(__MODULE__, :current_message_patterns)
      Module.delete_attribute(__MODULE__, :guard_registry)
      Module.delete_attribute(__MODULE__, :pattern_priority_counter)
    end
  end

  @doc """
  I merge function handlers and complex pattern rules, with function handlers taking precedence.
  """
  def merge_behavior_rules(function_rules, complex_pattern_rules) do
    # Convert to maps for easy merging
    function_map = Map.new(function_rules)
    complex_map = Map.new(complex_pattern_rules)

    # Function handlers override complex patterns
    merged_map = Map.merge(complex_map, function_map)

    # Convert back to list
    Map.to_list(merged_map)
  end

  # Helper functions that will be available at compile time
  # Wildcard pattern
  defp guard_arity({:_, _, _}), do: 0
  # Has pattern matching
  defp guard_arity(_), do: 1

  def get_current_message_type(patterns) do
    # Get the most recently added message type
    patterns
    |> Map.keys()
    |> List.last()
  end

  def compile_patterns_to_rules(message_patterns, guard_registry) do
    Enum.map(message_patterns, fn {msg_type, msg_data} ->
      compiled_patterns = compile_message_patterns(msg_data, guard_registry)
      {msg_type, {:complex_patterns, compiled_patterns}}
    end)
  end

  def compile_message_patterns(msg_data, guard_registry) do
    %{
      payload_pattern: msg_data.payload_pattern,
      patterns: Enum.sort_by(msg_data.patterns, & &1.priority),
      guard_registry: guard_registry
    }
  end

  # Compile the new guard syntax
  defp compile_guard_syntax(guard_expr) do
    Macro.postwalk(guard_expr, fn
      # Simple atom reference: :guard_name
      atom when is_atom(atom) and atom != :and and atom != :or and atom != :not ->
        {:guard_ref, atom, quote(do: msg)}

      # Function call: :guard_name(args)
      {{:., _, [atom]}, _, args} when is_atom(atom) ->
        payload =
          case args do
            [] -> quote(do: msg)
            [single_arg] -> single_arg
            multiple_args -> {:__block__, [], multiple_args}
          end

        {:guard_ref, atom, payload}

      # Keep other expressions as-is
      other ->
        other
    end)
  end

  # Compile with-guard syntax for data-returning guards
  defp compile_with_guard_syntax(bindings) do
    case bindings do
      # Single binding: var <- :guard_name(args)
      {:<-, _, [var, guard_call]} ->
        compiled_guard = compile_guard_syntax(guard_call)
        {:with_guard, var, compiled_guard}

      # Multiple bindings (future enhancement)
      _ ->
        raise CompileError, description: "Complex with_guard patterns not yet implemented"
    end
  end

  # Legacy compatibility functions
  @doc """
  I validate behavior rules (legacy compatibility).
  """
  @spec validate_behaviour_rules(list()) :: :ok | {:error, any()}
  def validate_behaviour_rules(rules) when is_list(rules) do
    validate_rules(rules)
  end

  def validate_behaviour_rules(_), do: {:error, :invalid_behaviour_rules}

  defp validate_rules([]), do: :ok

  defp validate_rules([{tag, _handler} | rest]) when is_atom(tag) do
    validate_rules(rest)
  end

  defp validate_rules(_), do: {:error, :invalid_rule_definition}

  @doc """
  I check if a message tag has a handler defined (enhanced version).

  ## Example

  ```elixir
  if BehaviorBuilder.has_handler?(:save_document, engine_rules) do
    # Process save document message
  end
  ```
  """
  @spec has_handler?(atom(), list()) :: boolean()
  def has_handler?(tag, behaviour_rules) do
    Enum.any?(behaviour_rules, fn
      {rule_tag, _handler} when rule_tag == tag -> true
      _ -> false
    end)
  end

  @doc """
  I get the handler for a specific message tag (enhanced version).

  ## Example

  ```elixir
  case BehaviorBuilder.get_handler(:update_profile, engine_rules) do
    {:ok, handler} -> execute_handler(handler, message, state)
    {:error, :not_found} -> handle_unknown_message(message)
  end
  ```
  """
  @spec get_handler(atom(), list()) :: {:ok, any()} | {:error, :not_found}
  def get_handler(tag, behaviour_rules) do
    case Enum.find(behaviour_rules, fn
           {rule_tag, _handler} when rule_tag == tag -> true
           _ -> false
         end) do
      {^tag, handler} -> {:ok, handler}
      nil -> {:error, :not_found}
    end
  end
end
