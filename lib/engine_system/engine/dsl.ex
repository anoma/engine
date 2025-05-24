defmodule EngineSystem.Engine.DSL do
  @moduledoc """
  I provide the Domain Specific Language (DSL) for defining Engine System engine types.

  This module contains macros like `defengine`, `config`, `env`, `messages`,
  `behaviour`, and `guarded_action` that allow users to declaratively specify
  the structure and behavior of their engines.

  These definitions are then compiled into `EngineSystem.Engine.Compilation.Types.EngineSpec` structs.

  ### Public API

  The macros defined herein constitute the public API:

  - `defengine/2`
  - `config/1` or `config/2`
  - `env/1` or `env/2`
  - `messages/1`
  - `message/2`
  - `behaviour/1`
  - `guarded_action/3`
  """

  alias EngineSystem.Engine.Compilation.Types.{
    BehaviourSpec,
    ConfigSpec,
    EngineSpec,
    EnvSpec,
    GuardedActionSpec,
    MessageInterfaceSpec,
    MessageSpec
  }

  # DSL macro export
  defmacro __using__(_opts) do
    quote do
      import EngineSystem.Engine.DSL,
        only: [
          defengine: 2,
          config: 1,
          config: 2,
          env: 1,
          env: 2,
          messages: 1,
          message: 1,
          message: 2,
          behaviour: 1,
          guarded_action: 3
        ]
    end
  end

  @doc """
  I define a new engine type with a given name, version, and a block of DSL definitions.

  This macro will generate a module that stores the compiled `EngineSpec.t()` for this engine type.
  It also registers the engine type with `EngineSystem.System.Services`.

  ## Examples

      defmodule MyApp.MyKVStoreEngine do
        use EngineSystem.Engine.DSL

        defengine MyApp.KVStore, version: "1.0" do
          config do
            %{parent: nil, mode: :process}
          end

          env do
            %{store: %{}, access_count: %{}}
          end

          messages do
            message :put, params: [:key, :value]
            message :get, params: [:key]
            message :delete, params: [:key]
            message :result, params: [:value_option]
          end

          behaviour do
            guarded_action :get, [key], env: e, when: is_map_key(e.store, key) do
              [
                {:update, Map.update(e, :access_count, %{}, fn counts ->
                  Map.update(counts, key, 1, &(&1 + 1))
                end)},
                {:send, sender, {:result, Map.get(e.store, key)}}
              ]
            end
          end
        end
      end
  """
  defmacro defengine(engine_type_name_ast, options_and_do_block) do
    expanded_opts_and_do_block =
      case options_and_do_block do
        kw when is_list(kw) -> kw
        {:do, actual_block_content} -> [{:do, actual_block_content}]
        _ -> raise "Invalid options or do_block for defengine: #{inspect(options_and_do_block)}"
      end

    {do_block_content, options_list} = Keyword.pop(expanded_opts_and_do_block, :do)
    unless do_block_content, do: raise("defengine requires a do/end block.")

    options = Enum.into(options_list, %{})
    version = Map.get(options, :version, "0.0.0")

    _default_mode = Map.get(options, :mode, :process)
    _default_parent = Map.get(options, :parent, nil)

    resolved_engine_type_name =
      case engine_type_name_ast do
        {:__aliases__, _, parts} -> Module.concat(parts)
        name when is_atom(name) -> name
        _ -> raise "Invalid engine type name: #{Macro.to_string(engine_type_name_ast)}"
      end

    version_suffix = "V" <> String.replace(to_string(version), ".", "_")

    definition_module_name_parts =
      [EngineSystem.Definitions, resolved_engine_type_name, String.to_atom(version_suffix)]

    definition_module_name = Module.concat(definition_module_name_parts)

    quote location: :keep do
      Module.register_attribute(__MODULE__, :engine_dsl_config_spec, accumulate: false)
      Module.register_attribute(__MODULE__, :engine_dsl_env_spec, accumulate: false)
      Module.register_attribute(__MODULE__, :engine_dsl_messages, accumulate: true, default: [])

      Module.register_attribute(__MODULE__, :engine_dsl_guarded_actions,
        accumulate: true,
        default: []
      )

      unquote(do_block_content)

      retrieved_config_spec_details = Module.get_attribute(__MODULE__, :engine_dsl_config_spec)
      retrieved_env_spec_details = Module.get_attribute(__MODULE__, :engine_dsl_env_spec)

      retrieved_messages_spec_list =
        Module.get_attribute(__MODULE__, :engine_dsl_messages) |> Enum.reverse()

      retrieved_guarded_actions_list =
        Module.get_attribute(__MODULE__, :engine_dsl_guarded_actions) |> Enum.reverse()

      actual_config_spec_details =
        if retrieved_config_spec_details do
          retrieved_config_spec_details
        else
          %{
            initial_value_ast:
              quote(
                do: %{
                  parent: nil,
                  mode: :process
                }
              ),
            module: nil
          }
        end

      actual_env_spec_details =
        retrieved_env_spec_details ||
          %{initial_value_ast: quote(do: %{}), module: nil}

      config_spec =
        struct!(ConfigSpec, actual_config_spec_details)

      env_spec = struct!(EnvSpec, actual_env_spec_details)

      message_interface_spec = %MessageInterfaceSpec{
        messages: retrieved_messages_spec_list
      }

      behaviour_spec = %BehaviourSpec{
        guarded_actions: retrieved_guarded_actions_list
      }

      engine_spec = %EngineSpec{
        type_name: unquote(resolved_engine_type_name),
        type_version: unquote(version),
        config_spec: config_spec,
        env_spec: env_spec,
        message_interface_spec: message_interface_spec,
        behaviour_spec: behaviour_spec
      }

      @engine_system_type_name unquote(resolved_engine_type_name)
      @engine_system_type_version unquote(version)
      @engine_system_spec engine_spec
      @engine_system_definition_module unquote(definition_module_name)

      def __engine_spec__, do: @engine_system_spec
      def __engine_definition_module__, do: @engine_system_definition_module

      EngineSystem.Engine.DSL.__register_engine__(
        __ENV__,
        @engine_system_type_name,
        @engine_system_type_version,
        @engine_system_spec,
        @engine_system_definition_module
      )
    end
  end

  def __register_engine__(env, type_name, type_version, spec, definition_module) do
    module = env.module

    require Logger

    Logger.debug(
      "DSL.__register_engine__ called for: #{inspect(type_name)} v#{inspect(type_version)} from module #{inspect(module)}"
    )

    result =
      EngineSystem.System.Services.register_engine_type_spec(
        type_name,
        type_version,
        module,
        spec,
        definition_module
      )

    Logger.debug("DSL.__register_engine__ registration result: #{inspect(result)}")
    :ok
  end

  @doc """
  I define the configuration structure for an engine.

  The configuration specifies metadata about the engine such as its parent,
  operational mode, and other engine-type-specific configuration as described
  in section 3.4 of the formal model.

  ## Examples

      config do
        %{parent: nil, mode: :process, type: :read_write}
      end

      # Or with options
      config module: MyApp.KVStoreConfig do
        %MyApp.KVStoreConfig{parent: nil, mode: :process, type: :read_write}
      end
  """
  defmacro config(options \\ [], do: config_ast) do
    options_map =
      case options do
        options_list when is_list(options_list) -> Enum.into(options_list, %{})
        _ -> %{}
      end

    module_opt = Map.get(options_map, :module)

    quote do
      Module.put_attribute(__MODULE__, :engine_dsl_config_spec, %{
        initial_value_ast: unquote(Macro.escape(config_ast)),
        module: unquote(module_opt)
      })
    end
  end

  @doc """
  I define the environment (local state) structure for an engine.

  The environment represents the local state of the engine, including the address book
  (mapping of names to addresses) as described in section 3.5 of the formal model.

  ## Examples

      env do
        %{store: %{}, access_count: %{}}
      end

      # Or with options
      env module: MyApp.KVStoreState do
        %MyApp.KVStoreState{store: %{}, access_count: %{}}
      end
  """
  defmacro env(options \\ [], do: env_ast) do
    options =
      case options do
        options when is_list(options) -> Enum.into(options, %{})
        _ -> %{}
      end

    module_opt = Map.get(options, :module, nil)

    quote do
      Module.put_attribute(__MODULE__, :engine_dsl_env_spec, %{
        module: unquote(module_opt),
        initial_value_ast: unquote(Macro.escape(env_ast))
      })
    end
  end

  @doc """
  I define the message interface for an engine.

  This block contains message definitions that specify what message types the engine
  can process, as described in section 3.3 of the formal model.

  ## Examples

      messages do
        message :put, params: [:key, :value]
        message :get, params: [:key]
        message :delete, params: [:key]
      end
  """
  defmacro messages(do: messages_block) do
    quote do
      unquote(messages_block)
    end
  end

  @doc """
  I define a single message type within the message interface of an engine.

  This macro should be used within a messages/1 block.

  ## Options

  - `:params` - A list of parameter names for the message payload
  - `:type` - A module defining a struct for the message payload

  ## Examples

      message :put, params: [:key, :value]
      message :get, params: [:key]
      message :result, type: MyApp.ResultPayload
  """
  defmacro message(tag, options \\ []) do
    params_ast = Keyword.get(options, :params, [])

    payload_params_ast =
      if is_list(params_ast), do: quote(do: unquote(params_ast)), else: params_ast

    payload_struct_module = Keyword.get(options, :payload_struct_module, nil)

    quote do
      message_spec = %MessageSpec{
        tag: unquote(tag),
        payload_params_ast: unquote(Macro.escape(payload_params_ast)),
        payload_struct_module: unquote(payload_struct_module)
      }

      Module.put_attribute(__MODULE__, :engine_dsl_messages, message_spec)
    end
  end

  @doc """
  Defines the behaviour of an engine as a collection of guarded actions.

  The behaviour specifies how the engine reacts to messages through guarded actions
  (pairs of guards and actions), as described in section 3.7 of the formal model.

  ## Examples

      behaviour do
        guarded_action :get, [key], env: e, when: is_map_key(e.store, key) do
          [
            {:update, Map.update(e, :access_count, %{}, fn counts ->
              Map.update(counts, key, 1, &(&1 + 1))
            end)},
            {:send, sender, {:result, Map.get(e.store, key)}}
          ]
        end

        # ... more guarded actions
      end
  """
  defmacro behaviour(do: behaviour_block) do
    quote do
      unquote(behaviour_block)
    end
  end

  @doc """
  Defines a single guarded action within the behaviour of an engine.

  This macro should be used within a behaviour/1 block. A guarded action specifies
  a pattern match on a message, context bindings, a guard condition, and the action
  to execute when the guard is satisfied.

  ## Parameters

  - `message_tag` - The tag of the message this action handles
  - `payload_bindings` - List of variables to bind from the message payload
  - `options` - Keyword list of options including:
    - `:config` - Variable to bind the engine's configuration
    - `:env` - Variable to bind the engine's environment (local state)
    - `:sender` - Variable to bind the message sender address
    - `:when` - Guard expression that must be satisfied
  - `do_block` - The action to execute when the guard is satisfied

  ## Examples

      guarded_action :get, [key], env: e, when: is_map_key(e.store, key) do
        [
          {:update, Map.update(e, :access_count, %{}, fn counts ->
            Map.update(counts, key, 1, &(&1 + 1))
          end)},
          {:send, sender, {:result, Map.get(e.store, key)}}
        ]
      end
  """
  defmacro guarded_action(message_tag, payload_bindings, options_and_do_block) do
    {do_block, options_kw} = Keyword.pop(options_and_do_block, :do)
    options_map = Enum.into(options_kw, %{})
    config_var_ast = Map.get(options_map, :config, quote(do: _config))
    env_var_ast = Map.get(options_map, :env, quote(do: _env))
    sender_var_ast = Map.get(options_map, :sender, quote(do: sender))
    guard_expr_ast = Map.get(options_map, :when, true)
    payload_bindings_qast = quote do: unquote(payload_bindings)

    context_bindings_qast =
      quote do
        %{
          config: unquote(config_var_ast),
          env: unquote(env_var_ast),
          sender: unquote(sender_var_ast)
        }
      end

    action_qast = do_block

    quote do
      guarded_action_spec = %GuardedActionSpec{
        message_tag: unquote(message_tag),
        payload_bindings_ast: unquote(Macro.escape(payload_bindings_qast)),
        context_bindings_ast: unquote(Macro.escape(context_bindings_qast)),
        guard_ast: unquote(Macro.escape(guard_expr_ast)),
        action_ast: unquote(Macro.escape(action_qast))
      }

      Module.put_attribute(__MODULE__, :engine_dsl_guarded_actions, guarded_action_spec)
    end
  end
end
