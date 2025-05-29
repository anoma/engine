defmodule EngineSystem.Engine.Compiler do
  @moduledoc """
  I provide engine compilation functionality to generate optimized engine files.

  This module handles the compilation of engine specifications into performant
  runtime code.
  """

  require Logger

  @doc """
  I generate a compiled engine file from an engine specification.

  ## Parameters

  - `spec` - The engine specification to compile
  - `source_file` - The source file path

  ## Returns

  `:ok` if successful, `{:error, reason}` if compilation fails
  """
  @spec generate_compiled_engine(struct(), String.t()) :: :ok | {:error, any()}
  def generate_compiled_engine(spec, source_file) do
    # Generate the compiled engine module name
    compiled_module_name = generate_compiled_module_name(spec.name)

    # Generate the output file path
    output_path = generate_output_path(source_file, compiled_module_name)

    # Generate the compiled code
    compiled_code = generate_compiled_code(spec, compiled_module_name)

    # Write the compiled file
    case File.write(output_path, compiled_code) do
      :ok ->
        Logger.debug("Generated compiled engine: #{output_path}")
        :ok

      {:error, reason} ->
        Logger.error("Failed to write compiled engine file: #{inspect(reason)}")
        {:error, reason}
    end
  rescue
    exception ->
      Logger.error("Compilation failed: #{Exception.message(exception)}")
      {:error, {:compilation_failed, exception}}
  end

  # Generate the compiled module name
  defp generate_compiled_module_name(engine_name) do
    module_parts = Module.split(engine_name)
    compiled_name = List.last(module_parts) <> "Compiled"

    case module_parts do
      [single] -> Module.concat([single <> "Compiled"])
      parts -> Module.concat(List.replace_at(parts, -1, compiled_name))
    end
  end

  # Generate the output file path
  defp generate_output_path(source_file, _compiled_module_name) do
    source_dir = Path.dirname(source_file)
    base_name = Path.basename(source_file, ".ex")
    compiled_name = base_name <> "_compiled.ex"
    Path.join(source_dir, compiled_name)
  end

  # Generate the compiled code content
  defp generate_compiled_code(spec, compiled_module_name) do
    """
    # This file was automatically generated from #{spec.name}
    # Do not edit manually - it will be overwritten on next compilation

    defmodule #{inspect(compiled_module_name)} do
      @moduledoc \"\"\"
      Compiled engine implementation for #{spec.name}.

      This module provides optimized runtime behavior for the engine.
      \"\"\"

      @spec_data #{inspect(spec, limit: :infinity, pretty: true)}

      def get_spec(), do: @spec_data

      def get_name(), do: #{inspect(spec.name)}

      def get_version(), do: #{inspect(spec.version)}

      def get_interface(), do: #{inspect(spec.interface, limit: :infinity)}

      def get_behaviour_rules(), do: #{inspect(spec.behaviour_rules, limit: :infinity)}

      def get_config_spec(), do: #{inspect(spec.config_spec, limit: :infinity)}

      def get_env_spec(), do: #{inspect(spec.env_spec, limit: :infinity)}

      def get_message_filter(), do: #{inspect(spec.message_filter, limit: :infinity)}

      # Runtime optimization helpers
      def has_handler?(message_tag) do
        # Fast lookup for message handlers
        #{generate_handler_lookup(spec.behaviour_rules)}
      end

      def get_handler(message_tag) do
        # Optimized handler retrieval
        #{generate_handler_getter(spec.behaviour_rules)}
      end
    end
    """
  end

  # Generate optimized handler lookup code
  defp generate_handler_lookup(behaviour_rules) do
    case behaviour_rules do
      [] ->
        "false"

      rules ->
        tags = Enum.map(rules, fn {tag, _} -> inspect(tag) end)
        "message_tag in [#{Enum.join(tags, ", ")}]"
    end
  end

  # Generate optimized handler getter code
  defp generate_handler_getter(behaviour_rules) do
    case behaviour_rules do
      [] ->
        "{:error, :not_found}"

      rules ->
        clauses =
          Enum.map(rules, fn {tag, handler} ->
            "      #{inspect(tag)} -> {:ok, #{inspect(handler, limit: :infinity)}}"
          end)

        """
        case message_tag do
        #{Enum.join(clauses, "\n")}
          _ -> {:error, :not_found}
        end
        """
    end
  end
end
