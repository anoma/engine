defmodule EngineSystem.Engine.DSL do
  @moduledoc """
  I provide macros to define Engine Types using a Domain Specific Language.

  This module implements the `defengine` macro and other helper macros that allow
  users to define engines with their message interfaces, configurations,
  environments, and behaviors.

  """

  alias EngineSystem.Engine.{DiagramGenerator, Spec}
  alias EngineSystem.Engine.DSL.Validation
  alias EngineSystem.System.Registry

  @doc """
  I define an engine type using the DSL.
  """
  defmacro defengine(name_ast, do: block) do
    defengine_impl(name_ast, [], block)
  end

  defmacro defengine(name_ast, opts, do: block) do
    defengine_impl(name_ast, opts, block)
  end

  @doc """
  I set the engine version.
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
  I finalize the engine spec before compilation.
  """
  defmacro __before_compile__(env) do
    # Get the spec data at compile time
    spec_data = Module.get_attribute(env.module, :engine_spec_data)
    generate_compiled = Module.get_attribute(env.module, :generate_compiled)
    generate_diagrams = Module.get_attribute(env.module, :generate_diagrams)

    # Process and validate the spec data
    final_spec = build_final_spec(spec_data, env)

    generate_engine_functions(final_spec, generate_compiled, generate_diagrams)
  end

  defp build_final_spec(spec_data, env) do
    # Set default mode and validate
    validated_spec_data = validate_and_set_mode(spec_data, env)

    # Set default specs
    final_config_spec = get_final_config_spec(validated_spec_data)
    final_env_spec = get_final_env_spec(validated_spec_data)

    # Create the final EngineSpec struct
    final_spec = create_final_spec(validated_spec_data, final_config_spec, final_env_spec)

    # Validate the final spec
    validate_final_spec(final_spec, env)

    final_spec
  end

  defp validate_and_set_mode(spec_data, env) do
    if is_nil(spec_data.mode) do
      %{spec_data | mode: :process}
    else
      unless spec_data.mode in [:process, :mailbox] do
        raise CompileError,
          file: env.file,
          line: env.line,
          description:
            "Invalid engine mode: #{inspect(spec_data.mode)}. Mode must be :process or :mailbox"
      end

      spec_data
    end
  end

  defp get_final_config_spec(spec_data) do
    if spec_data.config_spec == %{} do
      %{
        name: :default_config,
        default: default_config_for_mode(spec_data.mode),
        fields: []
      }
    else
      spec_data.config_spec
    end
  end

  defp get_final_env_spec(spec_data) do
    if spec_data.env_spec == %{} do
      %{
        name: :stateless_env,
        default: default_environment_for_mode(spec_data.mode),
        fields: []
      }
    else
      spec_data.env_spec
    end
  end

  defp create_final_spec(spec_data, final_config_spec, final_env_spec) do
    %Spec{
      name: spec_data.name,
      version: spec_data.version,
      interface: spec_data.interface,
      config_spec: final_config_spec,
      env_spec: final_env_spec,
      behaviour_rules: spec_data.behaviour_rules,
      message_filter: spec_data.message_filter,
      mode: spec_data.mode
    }
  end

  defp validate_final_spec(final_spec, env) do
    case Validation.validate_engine_spec(final_spec) do
      :ok ->
        :ok

      {:error, reason} ->
        raise CompileError,
          file: env.file,
          line: env.line,
          description: "Invalid engine specification: #{inspect(reason)}"
    end
  end

  defp generate_engine_functions(final_spec, generate_compiled, generate_diagrams) do
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
        do_register_spec(spec)

        handle_post_compilation(
          spec,
          env.file,
          unquote(generate_compiled),
          unquote(generate_diagrams)
        )
      end

      unquote(generate_helper_functions())
    end
  end

  defp generate_helper_functions do
    quote do
      unquote(generate_registration_functions())
      unquote(generate_compilation_functions())
      unquote(generate_diagram_functions())
    end
  end

  defp generate_registration_functions do
    quote do
      defp do_register_spec(spec) do
        Registry.register_spec(spec)
      catch
        :exit, _ -> :ok
      end

      defp handle_post_compilation(spec, source_file, generate_compiled, generate_diagrams) do
        if should_compile?(generate_compiled) do
          handle_compilation(spec, source_file)
        end

        if should_generate_diagrams?(generate_diagrams) do
          handle_diagram_generation(spec)
        end
      end
    end
  end

  defp generate_compilation_functions do
    quote do
      defp should_compile?(local_flag) do
        local_flag or Application.get_env(:engine_system, :compile_engines, false)
      end

      defp handle_compilation(spec, source_file) do
        IO.puts("📝 Compilation enabled for #{spec.name} (implementation pending)")
      catch
        kind, reason ->
          IO.warn(
            "Failed to generate compiled engine for #{spec.name}: #{inspect({kind, reason})}"
          )
      end
    end
  end

  defp generate_diagram_functions do
    quote do
      defp should_generate_diagrams?(local_flag) do
        local_flag or Application.get_env(:engine_system, :generate_diagrams, false)
      end

      defp handle_diagram_generation(spec) do
        generate_single_diagram(spec)
        schedule_compilation_diagrams()
      catch
        kind, reason ->
          IO.warn("Failed to generate diagram for #{spec.name}: #{inspect({kind, reason})}")
      end

      defp generate_single_diagram(spec) do
        diagram_options = %{
          output_dir: Application.get_env(:engine_system, :diagram_output_dir, "docs/diagrams"),
          include_metadata: true,
          diagram_title: "#{spec.name} Communication Flow",
          file_prefix: ""
        }

        case DiagramGenerator.generate_diagram(spec, nil, diagram_options) do
          {:ok, file_path} ->
            IO.puts("📊 Generated diagram for #{spec.name}: #{file_path}")

          {:error, reason} ->
            IO.warn("Failed to generate diagram for #{spec.name}: #{inspect(reason)}")
        end
      end

      defp schedule_compilation_diagrams do
        spawn(fn ->
          Process.sleep(100)
          DiagramGenerator.generate_compilation_diagrams()
        end)
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
