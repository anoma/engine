defmodule EngineSystem.Engine.DSL do
  @moduledoc """
  I provide macros to define Engine Types using a Domain Specific Language.

  This module implements the `defengine` macro and other helper macros that allow
  users to define engines with their message interfaces, configurations,
  environments, and behaviors.

  ## Example Usage

  ```elixir
  defengine KVStoreEngine do
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
      on_message :get do |msg_payload, config_data, env_data, msg_sender_address|
        # Implementation logic here
        {:ok, :noop}
      end

      on_message :put do |msg_payload, config_data, env_data, msg_sender_address|
        # Implementation logic here
        {:ok, :noop}
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

  This macro processes the engine Def. and creates a compiled EngineSpec
  that gets registered with the system.
  """
  defmacro defengine(name_ast, do: block) do
    quote do
      defmodule unquote(name_ast) do
        @before_compile EngineSystem.Engine.DSL

        # Initialize spec accumulator
        Module.register_attribute(__MODULE__, :engine_spec_data, accumulate: false)

        Module.put_attribute(__MODULE__, :engine_spec_data, %{
          name: unquote(name_ast),
          version: "0.1.0",
          interface: [],
          config_spec: %{},
          env_spec: %{},
          behaviour_rules: [],
          message_filter: {:default_filter, []}
        })

        # Import DSL macros
        import EngineSystem.Engine.DSL,
          only: [
            version: 1,
            environment: 2,
            message_filter: 1
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
            field: 2,
            field: 1
          ]

        import EngineSystem.Engine.DSL.BehaviorBuilder,
          only: [
            behaviour: 1,
            on_message: 2
          ]

        # Process the block
        unquote(block)
      end
    end
  end

  @doc """
  I set the version for the engine.
  """
  defmacro version(version_string) do
    quote do
      spec_data = Module.get_attribute(__MODULE__, :engine_spec_data)
      updated_spec = %{spec_data | version: unquote(version_string)}
      Module.put_attribute(__MODULE__, :engine_spec_data, updated_spec)
    end
  end

  @doc """
  I define the environment structure for the engine.
  """
  defmacro environment(env_args, do: block) do
    quote do
      Module.put_attribute(__MODULE__, :current_env_fields, [])
      unquote(block)

      spec_data = Module.get_attribute(__MODULE__, :engine_spec_data)
      fields = Module.get_attribute(__MODULE__, :current_env_fields) |> Enum.reverse()

      # Extract name and default from the keyword list
      [{env_name, default_value}] = unquote(env_args)

      env_spec = %{
        name: env_name,
        default: default_value,
        fields: fields
      }

      updated_spec = %{spec_data | env_spec: env_spec}
      Module.put_attribute(__MODULE__, :engine_spec_data, updated_spec)
      Module.delete_attribute(__MODULE__, :current_env_fields)
    end
  end

  @doc """
  I define a field in the environment.
  """
  defmacro field(name, options \\ []) do
    quote do
      field_def = {unquote(name), unquote(options)}

      # Add to current env fields if we're in env context
      if Module.has_attribute?(__MODULE__, :current_env_fields) do
        current_fields = Module.get_attribute(__MODULE__, :current_env_fields)
        Module.put_attribute(__MODULE__, :current_env_fields, [field_def | current_fields])
      end
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
  I am called before compilation completes to finalize the engine spec.
  """
  defmacro __before_compile__(env) do
    # Get the spec data at compile time
    spec_data = Module.get_attribute(env.module, :engine_spec_data)

    # Provide default config_spec if none was defined
    final_config_spec =
      if spec_data.config_spec == %{} do
        %{
          name: :default_config,
          default: %{parent: nil, mode: :process},
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
          default: %{},
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
      message_filter: spec_data.message_filter
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

      def __after_compile__(_env, _bytecode) do
        spec = __engine_spec__()
        # Try to register the spec, but don't fail if the system isn't running
        try do
          Registry.register_spec(spec)
        catch
          # System not running, that's fine
          :exit, _ -> :ok
        end
      end
    end
  end
end
