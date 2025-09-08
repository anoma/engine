defmodule EngineSystem.Engine.DSL do
  @moduledoc """
  I provide macros to define Engine Types using a Domain Specific Language.

  This module implements the `defengine` macro and other helper macros that allow
  users to define engines with their message interfaces, configurations,
  environments, and behaviors.

  ## File Compilation

  By default, engines do not generate compiled files. To enable file compilation:

  1. Use the `:compile` option: `defengine MyEngine, compile: true do`
  2. Set the global application configuration: `config :engine_system, compile_engines: true`

  The `:compile` option takes precedence over the global configuration.

  ## Example Usage

  ```elixir
  defengine KVStoreEngine, compile: true do
    version "1.0.0"

    interface do
      message :put, key: :atom, value: :any
      message :get, key: :atom
      message :delete, key: :atom
      message :result, value: {:option, :any}
      message :ack
    end

    config kv_config_type: %{access_mode: :read_write} do
      field :access_mode, default: :read_write, type: :atom
    end

    environment initial_data: %{store: %{}, access_counts: %{}} do
      field :store, default: %{}, type: :map
      field :access_counts, default: %{}, type: :map
    end

    message_filter fn _msg, _config, _env -> true end

    behaviour do
      on_message :get, %{key: key} when is_atom(key) do
        # Implementation logic here
        {:ok, [{:send, msg_sender_address, {:result, env_data.store[key]}}]}
      end

      on_message :put, %{key: key, value: value} do
        # Implementation logic here
        new_env = %{env_data | store: Map.put(env_data.store, key, value)}
        {:ok, [{:update_environment, new_env}, {:send, msg_sender_address, :ack}]}
      end
    end
  end
  ```
  """

  alias EngineSystem.Engine.DSL.Validation
  alias EngineSystem.Engine.Spec
  alias EngineSystem.System.Registry

  @doc """
  I define an engine type using the DSL.

  This macro processes the engine definition and creates a compiled EngineSpec
  that gets registered with the system.

  By default, no compiled files or diagrams are generated. Use the `:compile` option
  (`defengine MyEngine, compile: true do`) or set the global `:compile_engines`
  application configuration to enable file compilation.

  ## Options

  - `:compile` - When `true`, enables compiled file generation for this engine
  - `:generate_diagrams` - When `true`, enables Mermaid diagram generation for this engine

  ## Examples

  ```elixir
  # Basic engine without compilation or diagrams
  defengine MyEngine do
    version "1.0.0"
    # ... rest of definition
  end

  # Engine with compilation enabled
  defengine MyEngine, compile: true do
    version "1.0.0"
    # ... rest of definition
  end

  # Engine with diagram generation enabled
  defengine MyEngine, generate_diagrams: true do
    version "1.0.0"
    # ... rest of definition
  end

  # Engine with both compilation and diagram generation
  defengine MyEngine, compile: true, generate_diagrams: true do
    version "1.0.0"
    # ... rest of definition
  end
  ```
  """
  defmacro defengine(name_ast, do: block) do
    defengine_impl(name_ast, [], block)
  end

  defmacro defengine(name_ast, opts, do: block) do
    defengine_impl(name_ast, opts, block)
  end

  @doc """
  I set the version for the engine without enabling file compilation.

  Use `defengine MyEngine, compile: true do` to enable file compilation if needed.
  """
  @spec version(String.t()) :: any()
  defmacro version(version_string) do
    quote do
      spec_data = Module.get_attribute(__MODULE__, :engine_spec_data)
      updated_spec = %{spec_data | version: unquote(version_string)}
      Module.put_attribute(__MODULE__, :engine_spec_data, updated_spec)
      :ok
    end
  end

  @doc """
  I set the engine mode (processing or mailbox).

  ## Parameters

  - `mode` - The engine mode: `:process` or `:mailbox`

  ## Examples

  ```elixir
  defengine MyProcessingEngine do
    mode :process  # Generates GenStage consumer
    # ...
  end

  defengine MyMailboxEngine do
    mode :mailbox  # Generates GenStage producer
    # ...
  end
  ```
  """
  defmacro mode(engine_mode) do
    quote do
      # Validate mode is valid
      case unquote(engine_mode) do
        :process ->
          :ok

        :mailbox ->
          :ok

        invalid_mode ->
          raise CompileError,
            description:
              "Invalid engine mode: #{inspect(invalid_mode)}. Must be :process or :mailbox"
      end

      spec_data = Module.get_attribute(__MODULE__, :engine_spec_data)
      updated_spec = %{spec_data | mode: unquote(engine_mode)}
      Module.put_attribute(__MODULE__, :engine_spec_data, updated_spec)
    end
  end

  @doc """
  I define the message filter function for the engine.

  The filter function is called for each incoming message to determine
  whether it should be processed by the engine. This allows you to implement
  custom message filtering logic based on message content, configuration,
  or current environment state.

  ## Parameters

  The filter function receives three parameters:
  - `message` - The incoming message payload
  - `config` - The engine's current configuration
  - `env` - The engine's current environment/state

  ## Returns

  The filter function must return:
  - `true` if the message should be processed
  - `false` if the message should be ignored/filtered out

  ## Examples

  ```elixir
  # Simple filter - accept all messages
  defengine MyEngine do
    message_filter fn _msg, _config, _env ->
      true
    end
  end
  ```

  ```elixir
  # Filter based on message type
  defengine SelectiveEngine do
    message_filter fn msg, _config, _env ->
      case msg do
        {:priority, _} -> true
        {:normal, _} -> false
        _ -> true
      end
    end
  end
  ```

  ```elixir
  # Filter based on configuration
  defengine ConfigurableEngine do
    message_filter fn msg, config, _env ->
      case config.access_mode do
        :read_only ->
          # Only allow read operations
          case msg do
            {:get, _} -> true
            {:list, _} -> true
            _ -> false
          end
        :read_write ->
          # Allow all operations
          true
      end
    end
  end
  ```

  ```elixir
  # Filter based on environment state
  defengine StatefulEngine do
    message_filter fn _msg, _config, env ->
      # Only process messages if we're not overloaded
      Map.get(env, :queue_size, 0) < 100
    end
  end
  ```

  ```elixir
  # Complex filter with pattern matching
  defengine AdvancedEngine do
    message_filter fn msg, config, env ->
      case {msg, config.mode, env.status} do
        # High priority messages always pass
        {{:urgent, _}, _, _} -> true
        # Normal messages only in active mode
        {{:normal, _}, :active, :running} -> true
        # Maintenance messages only in maintenance mode
        {{:maintenance, _}, :maintenance, _} -> true
        # Everything else is filtered out
        _ -> false
      end
    end
  end
  ```

  ## Notes

  - If no message_filter is defined, all messages are accepted by default
  - Filter functions should be fast and avoid side effects
  - Exceptions in filter functions will cause the message to be rejected
  - The filter is applied before message validation against the interface

  """
  defmacro message_filter(filter_ast) do
    quote do
      spec_data = Module.get_attribute(__MODULE__, :engine_spec_data)

      updated_spec = %{
        spec_data
        | message_filter: {:custom_filter, unquote(Macro.escape(filter_ast))}
      }

      Module.put_attribute(__MODULE__, :engine_spec_data, updated_spec)
    end
  end

  @doc """
  I am called before compilation completes to finalize the engine spec.
  """
  defmacro __before_compile__(env) do
    # Get the spec data at compile time
    spec_data = Module.get_attribute(env.module, :engine_spec_data)
    generate_compiled = Module.get_attribute(env.module, :generate_compiled)
    generate_diagrams = Module.get_attribute(env.module, :generate_diagrams)

    # If no mode is declared, default to :process
    # Valid modes are :process or :mailbox
    spec_data =
      if is_nil(spec_data.mode) do
        %{spec_data | mode: :process}
      else
        # Ensure the mode is valid
        unless spec_data.mode in [:process, :mailbox] do
          raise CompileError,
            file: env.file,
            line: env.line,
            description:
              "Invalid engine mode: #{inspect(spec_data.mode)}. Mode must be :process or :mailbox"
        end

        spec_data
      end

    # Provide default config_spec if none was defined
    final_config_spec =
      if spec_data.config_spec == %{} do
        %{
          name: :default_config,
          default: default_config_for_mode(spec_data.mode),
          fields: []
        }
      else
        spec_data.config_spec
      end

    # Provide default env_spec if none was defined (stateless engine)
    final_env_spec =
      if spec_data.env_spec == %{} do
        %{
          name: :stateless_env,
          default: default_environment_for_mode(spec_data.mode),
          fields: []
        }
      else
        spec_data.env_spec
      end

    # Create the final EngineSpec struct at compile time
    final_spec = %Spec{
      name: spec_data.name,
      version: spec_data.version,
      interface: spec_data.interface,
      config_spec: final_config_spec,
      env_spec: final_env_spec,
      behaviour_rules: spec_data.behaviour_rules,
      message_filter: spec_data.message_filter,
      mode: spec_data.mode
    }

    # Validate the spec at compile time
    case Validation.validate_engine_spec(final_spec) do
      :ok ->
        :ok

      {:error, reason} ->
        raise CompileError,
          file: env.file,
          line: env.line,
          description: "Invalid engine specification: #{inspect(reason)}"
    end

    quote do
      def __engine_spec__ do
        unquote(Macro.escape(final_spec))
      end

      # Auto-register the spec when the module is loaded
      def __on_definition__(_env, _kind, _name, _args, _guards, _body) do
        :ok
      end

      @after_compile __MODULE__

      def __after_compile__(env, _bytecode) do
        spec = __engine_spec__()

        # Register spec (existing functionality)
        try do
          Registry.register_spec(spec)
        catch
          # System not running, that's fine
          :exit, _ -> :ok
        end

        # Generate compiled engine file only if enabled
        # Check both local flag and global application configuration
        should_compile =
          unquote(generate_compiled) or
            Application.get_env(:engine_system, :compile_engines, false)

        if should_compile do
          source_file = env.file

          try do
            # EngineSystem.Engine.Compiler.generate_compiled_engine(spec, source_file)
            IO.puts("📝 Compilation enabled for #{spec.name} (implementation pending)")
          catch
            # Compilation failed, log but don't fail the build
            kind, reason ->
              IO.warn(
                "Failed to generate compiled engine for #{spec.name}: #{inspect({kind, reason})}"
              )
          end
        end

        # Generate Mermaid diagrams only if enabled
        # Check both local flag and global application configuration
        should_generate_diagrams =
          unquote(generate_diagrams) or
            Application.get_env(:engine_system, :generate_diagrams, false)

        if should_generate_diagrams do
          try do
            # Generate diagram for this engine with enhanced options
            diagram_options = %{
              output_dir: Application.get_env(:engine_system, :diagram_output_dir, "docs/diagrams"),
              include_metadata: true,
              diagram_title: "#{spec.name} Communication Flow",
              file_prefix: ""
            }

            case EngineSystem.Engine.DiagramGenerator.generate_diagram(spec, nil, diagram_options) do
              {:ok, file_path} ->
                IO.puts("📊 Generated diagram for #{spec.name}: #{file_path}")

              {:error, reason} ->
                IO.warn(
                  "Failed to generate diagram for #{spec.name}: #{inspect(reason)}"
                )
            end

            # Also trigger system-wide diagram generation if this is the last engine
            # compiled in a project (this is a heuristic approach)
            # In a real implementation, you might want a more sophisticated trigger
            spawn(fn ->
              # Small delay to allow other engines to compile first
              Process.sleep(100)
              EngineSystem.Engine.DiagramGenerator.generate_compilation_diagrams()
            end)

          catch
            # Diagram generation failed, log but don't fail the build
            kind, reason ->
              IO.warn(
                "Failed to generate diagram for #{spec.name}: #{inspect({kind, reason})}"
              )
          end
        end
      end
    end
  end

  # Helper functions for default values based on mode
  defp default_config_for_mode(:mailbox) do
    %{
      parent: nil,
      mode: :mailbox,
      # Default GenStage producer config
      producer_type: :demand_driven,
      max_demand: 100,
      min_demand: 10,
      batch_size: 20
    }
  end

  defp default_config_for_mode(:process) do
    %{parent: nil, mode: :process}
  end

  defp default_environment_for_mode(:mailbox) do
    %{
      # Default FIFO queue for mailbox engines
      message_queue: :queue.new(),
      current_demand: 0,
      total_received: 0,
      total_delivered: 0
    }
  end

  defp default_environment_for_mode(:process) do
    %{}
  end

  # Common implementation for defengine with options
  defp defengine_impl(name_ast, opts, block) do
    enable_compilation = Keyword.get(opts, :compile, false)
    enable_diagrams = Keyword.get(opts, :generate_diagrams, false)

    quote do
      defmodule unquote(name_ast) do
        @before_compile EngineSystem.Engine.DSL

        # Initialize spec accumulator
        Module.register_attribute(__MODULE__, :engine_spec_data, accumulate: false)
        # Track whether to generate compiled file (default: false)
        Module.register_attribute(__MODULE__, :generate_compiled, accumulate: false)
        # Track whether to generate diagrams (default: false)
        Module.register_attribute(__MODULE__, :generate_diagrams, accumulate: false)

        Module.put_attribute(__MODULE__, :engine_spec_data, %{
          name: unquote(name_ast),
          version: "0.1.0",
          mode: :process,
          interface: [],
          config_spec: %{},
          env_spec: %{},
          behaviour_rules: [],
          message_filter: {:default_filter, []}
        })

        Module.put_attribute(__MODULE__, :generate_compiled, unquote(enable_compilation))
        Module.put_attribute(__MODULE__, :generate_diagrams, unquote(enable_diagrams))

        # Import DSL macros
        import EngineSystem.Engine.DSL,
          only: [
            version: 1,
            message_filter: 1,
            # Mode is now mandatory
            mode: 1
          ]

        import EngineSystem.Engine.DSL.InterfaceBuilder,
          only: [
            interface: 1,
            message: 2,
            message: 1
          ]

        import EngineSystem.Engine.DSL.ConfigBuilder,
          only: [
            config: 2,
            config: 1,
            field: 2,
            field: 1
          ]

        import EngineSystem.Engine.DSL.EnvironmentBuilder,
          only: [
            environment: 2,
            environment: 1,
            env: 2,
            env: 1
          ]

        import EngineSystem.Engine.DSL.BehaviorBuilder,
          only: [
            behaviour: 1,
            on_message: 2,
            on_message: 3,
            on_message: 6,
            guard: 2,
            guard: 3,
            when_guard: 2,
            with_guard: 2,
            otherwise: 1,
            start_message_pattern_collection: 2,
            finalize_message_patterns: 1,
            finalize_behavior_with_guards: 0,
            compile_patterns_to_rules: 2,
            merge_behavior_rules: 2
          ]

        # Process the block
        unquote(block)
      end
    end
  end
end
