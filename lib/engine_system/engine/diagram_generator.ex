defmodule EngineSystem.Engine.DiagramGenerator do
  @moduledoc """
  I generate Mermaid message sequence diagrams from EngineSystem engine specifications.

  I analyze engine behaviour rules and message interfaces to create visual
  representations of communication patterns between engines. This provides
  automatic documentation of how engines interact with each other.

  ## Features

  - **Message Flow Analysis**: Extracts communication patterns from engine behaviour rules
  - **Mermaid Generation**: Creates Mermaid sequence diagram syntax
  - **File Output**: Writes diagrams to markdown files with proper formatting
  - **Multi-Engine Support**: Handles interactions between multiple engines
  - **Metadata Inclusion**: Adds generation timestamps and source information

  ## Usage

  ### Basic Usage

  ```elixir
  # Generate diagram for a single engine
  EngineSystem.Engine.DiagramGenerator.generate_diagram(engine_spec, "docs/diagrams/")

  # Generate multi-engine interaction diagram
  EngineSystem.Engine.DiagramGenerator.generate_multi_engine_diagram(engine_specs, "docs/diagrams/")
  ```

  ### Integration with DSL

  ```elixir
  defengine MyEngine, generate_diagrams: true do
    # engine definition
  end
  ```

  ## Generated Diagram Structure

  The generated diagrams follow this structure:

  ```mermaid
  sequenceDiagram
    participant Client
    participant Engine1 as MyEngine
    participant Engine2 as OtherEngine

    Client->>Engine1: message_type
    Note over Engine1: State change description
    Engine1->>Engine2: response_message
  ```

  ## Configuration

  - `:output_dir` - Directory to write diagram files (default: "docs/diagrams")
  - `:include_metadata` - Include generation metadata in diagrams (default: true)
  - `:diagram_title` - Custom title for generated diagrams
  """

  alias EngineSystem.Engine.{Effect, Spec, RuntimeFlowTracker}

  @type message_flow :: %{
    source_engine: atom(),
    target_engine: atom() | :dynamic | :sender,
    message_type: atom(),
    payload_pattern: any(),
    conditions: [any()],
    effects: [Effect.t()],
    handler_type: :function | :complex_pattern
  }

  @type runtime_enriched_flow :: %{
    source_engine: atom(),
    target_engine: atom() | :dynamic | :sender,
    message_type: atom(),
    payload_pattern: any(),
    conditions: [any()],
    effects: [Effect.t()],
    handler_type: :function | :complex_pattern,
    runtime_data: %{
      total_count: non_neg_integer(),
      success_rate: float(),
      avg_duration_ms: float() | nil,
      frequency_per_minute: float(),
      first_seen: integer(),
      last_seen: integer()
    } | nil
  }

  @type diagram_metadata :: %{
    title: String.t(),
    engines: [atom()],
    generated_at: DateTime.t(),
    source_files: [String.t()],
    version: String.t()
  }

  @type generation_options :: %{
    output_dir: String.t(),
    include_metadata: boolean(),
    diagram_title: String.t() | nil,
    file_prefix: String.t()
  }

  @default_options %{
    output_dir: "docs/diagrams",
    include_metadata: true,
    diagram_title: nil,
    file_prefix: ""
  }

  @doc """
  I generate a Mermaid sequence diagram for a single engine specification.

  ## Parameters

  - `spec` - The EngineSpec to analyze
  - `output_dir` - Directory to write the diagram file (optional)
  - `opts` - Additional generation options (optional)

  ## Returns

  - `{:ok, file_path}` if generation succeeded
  - `{:error, reason}` if generation failed

  ## Examples

      iex> spec = MyEngine.__engine_spec__()
      iex> EngineSystem.Engine.DiagramGenerator.generate_diagram(spec)
      {:ok, "docs/diagrams/my_engine.md"}

      iex> EngineSystem.Engine.DiagramGenerator.generate_diagram(spec, "custom/docs/", %{diagram_title: "Custom Title"})
      {:ok, "custom/docs/my_engine.md"}
  """
  @spec generate_diagram(Spec.t(), String.t() | nil, generation_options() | nil) ::
    {:ok, String.t()} | {:error, any()}
  def generate_diagram(spec, output_dir \\ nil, opts \\ nil) do
    try do
      options = merge_options(opts, output_dir)

      # Analyze message flows from the engine specification
      flows = analyze_message_flows(spec)

      # Generate Mermaid diagram syntax
      mermaid_content = generate_sequence_diagram(flows, spec, options)

      # Create output directory if it doesn't exist
      ensure_output_directory(options.output_dir)

      # Generate file path
      file_path = generate_file_path(spec, options)

      # Write diagram to file
      write_diagram_file(file_path, mermaid_content, options)

      {:ok, file_path}
    rescue
      error ->
        {:error, {:generation_failed, error}}
    end
  end

  @doc """
  I generate a runtime-refined diagram for a single engine specification.

  This combines compile-time flow analysis with runtime telemetry data to show
  actual usage patterns, message frequencies, and success rates.

  ## Parameters

  - `spec` - The EngineSpec to analyze
  - `output_dir` - Directory to write the diagram file (optional)
  - `opts` - Additional generation options (optional)

  ## Returns

  - `{:ok, file_path}` if generation succeeded
  - `{:error, reason}` if generation failed

  ## Examples

      iex> spec = MyEngine.__engine_spec__()
      iex> EngineSystem.Engine.DiagramGenerator.generate_runtime_refined_diagram(spec)
      {:ok, "docs/diagrams/my_engine_runtime.md"}
  """
  @spec generate_runtime_refined_diagram(Spec.t(), String.t() | nil, generation_options() | nil) ::
    {:ok, String.t()} | {:error, any()}
  def generate_runtime_refined_diagram(spec, output_dir \\ nil, opts \\ nil) do
    try do
      options = merge_options(opts, output_dir)

      # Get compile-time flows
      compile_flows = analyze_message_flows(spec)

      # Get runtime flow data
      runtime_flows = RuntimeFlowTracker.get_flow_data()

      # Merge compile-time and runtime data
      enriched_flows = enrich_flows_with_runtime_data(compile_flows, runtime_flows)

      # Generate runtime-enhanced Mermaid diagram
      mermaid_content = generate_runtime_enriched_sequence_diagram(enriched_flows, spec, options)

      # Create output directory
      ensure_output_directory(options.output_dir)

      # Generate file path with runtime suffix
      file_path = generate_runtime_file_path(spec, options)

      # Write diagram to file
      write_diagram_file(file_path, mermaid_content, options)

      {:ok, file_path}
    rescue
      error ->
        IO.puts("🐞 Error in generate_runtime_refined_diagram: #{inspect(error)}")
        IO.puts("🐞 Stacktrace:")
        IO.puts(Exception.format_stacktrace(__STACKTRACE__))
        {:error, {:generation_failed, error}}
    end
  end

  @doc """
  I generate a comprehensive system diagram showing all registered engines and their interactions.

  This function automatically discovers all registered engines in the system and creates
  a diagram showing their communication patterns.

  ## Parameters

  - `output_dir` - Directory to write the diagram file (optional)
  - `opts` - Additional generation options (optional)

  ## Returns

  - `{:ok, file_path}` if generation succeeded
  - `{:error, reason}` if generation failed

  ## Examples

      iex> EngineSystem.Engine.DiagramGenerator.generate_system_diagram()
      {:ok, "docs/diagrams/system_interaction.md"}
  """
  @spec generate_system_diagram(String.t() | nil, generation_options() | nil) ::
    {:ok, String.t()} | {:error, any()}
  def generate_system_diagram(output_dir \\ nil, opts \\ nil) do
    try do
      # Get all registered engine specs
      specs = get_all_registered_specs()
      
      if specs == [] do
        {:error, :no_engines_registered}
      else
        generate_multi_engine_diagram(specs, output_dir, opts)
      end
    rescue
      error ->
        {:error, {:system_diagram_failed, error}}
    end
  end

  @doc """
  I generate a Mermaid sequence diagram showing interactions between multiple engines.

  ## Parameters

  - `specs` - List of EngineSpecs to analyze
  - `output_dir` - Directory to write the diagram file (optional)
  - `opts` - Additional generation options (optional)

  ## Returns

  - `{:ok, file_path}` if generation succeeded
  - `{:error, reason}` if generation failed

  ## Examples

      iex> specs = [PingEngine.__engine_spec__(), PongEngine.__engine_spec__()]
      iex> EngineSystem.Engine.DiagramGenerator.generate_multi_engine_diagram(specs)
      {:ok, "docs/diagrams/ping_pong_interaction.md"}
  """
  @spec generate_multi_engine_diagram([Spec.t()], String.t() | nil, generation_options() | nil) ::
    {:ok, String.t()} | {:error, any()}
  def generate_multi_engine_diagram(specs, output_dir \\ nil, opts \\ nil) do
    try do
      options = merge_options(opts, output_dir)

      # Analyze message flows across all engines
      all_flows = Enum.flat_map(specs, &analyze_message_flows/1)

      # Filter flows that show interactions between engines
      interaction_flows = filter_interaction_flows(all_flows, specs)

      # Generate Mermaid diagram syntax
      mermaid_content = generate_multi_engine_sequence_diagram(interaction_flows, specs, options)

      # Create output directory if it doesn't exist
      ensure_output_directory(options.output_dir)

      # Generate file path
      file_path = generate_multi_engine_file_path(specs, options)

      # Write diagram to file
      write_diagram_file(file_path, mermaid_content, options)

      {:ok, file_path}
    rescue
      error ->
        {:error, {:generation_failed, error}}
    end
  end

  @doc """
  I analyze message flows from an engine specification.

  This function extracts communication patterns by parsing behaviour rules
  and identifying `{:send, target, payload}` effects.

  ## Parameters

  - `spec` - The EngineSpec to analyze

  ## Returns

  A list of message flow structures representing communication patterns.

  ## Examples

      iex> spec = PingEngine.__engine_spec__()
      iex> flows = EngineSystem.Engine.DiagramGenerator.analyze_message_flows(spec)
      iex> length(flows)
      3
  """
  @spec analyze_message_flows(Spec.t()) :: [message_flow()]
  def analyze_message_flows(spec) do
    spec.behaviour_rules
    |> Enum.flat_map(fn {message_type, handler} ->
      flows = extract_flows_from_handler(message_type, handler, spec.name)
      # Ensure each flow has proper metadata
      flows
      |> Enum.map(fn flow ->
        Map.merge(flow, %{
          engine_version: spec.version,
          engine_mode: Map.get(spec, :mode, :process)
        })
      end)
    end)
    |> Enum.filter(&(&1 != nil))
    |> deduplicate_flows()
  end

  # Remove duplicate flows that represent the same communication
  defp deduplicate_flows(flows) do
    flows
    |> Enum.uniq_by(fn flow ->
      {
        flow.source_engine,
        flow.target_engine,
        flow.message_type,
        flow.handler_type
      }
    end)
  end

  @doc """
  I generate Mermaid sequence diagram syntax from message flows.

  ## Parameters

  - `flows` - List of message flows to include in the diagram
  - `spec` - The primary engine specification
  - `options` - Generation options

  ## Returns

  A string containing valid Mermaid sequence diagram syntax.

  ## Examples

      iex> flows = [%{source_engine: :ping, target_engine: :pong, message_type: :ping, ...}]
      iex> EngineSystem.Engine.DiagramGenerator.generate_sequence_diagram(flows, spec, options)
      "sequenceDiagram\\n    participant Client\\n    ..."
  """
  @spec generate_sequence_diagram([message_flow()], Spec.t(), generation_options()) :: String.t()
  def generate_sequence_diagram(flows, spec, options) do
    # Generate diagram header
    header = generate_diagram_header(spec, options)

    # Generate participant declarations
    participants = generate_participants(flows, spec)

    # Generate message sequences
    sequences = generate_message_sequences(flows)

    # Generate metadata if requested
    metadata = if options.include_metadata do
      generate_metadata_section(spec, options)
    else
      ""
    end

    # Combine all parts
    [header, participants, sequences, metadata]
    |> Enum.filter(&(&1 != ""))
    |> Enum.join("\n")
  end

  # Private helper functions

  defp merge_options(opts, output_dir) do
    base_options = @default_options

    # Merge output directory if provided
    base_options = if output_dir, do: %{base_options | output_dir: output_dir}, else: base_options

    # Merge additional options if provided
    if opts do
      Map.merge(base_options, opts)
    else
      base_options
    end
  end

  defp extract_flows_from_handler(message_type, handler, engine_name) do
    case handler do
      {:function_handler, _module, function_name} ->
        # For function handlers, we know there's a message flow but can't
        # statically analyze the implementation. We create a placeholder
        # that shows the message is processed by the function.
        flows = [%{
          source_engine: :client,
          target_engine: engine_name,
          message_type: message_type,
          payload_pattern: :any,
          conditions: [],
          effects: [],
          handler_type: :function,
          metadata: %{function: function_name}
        }]
        
        # For known patterns, we can infer likely effects
        inferred_effects = infer_effects_from_function_name(function_name, message_type, engine_name)
        flows ++ inferred_effects

      {:complex_patterns, pattern_data} when is_map(pattern_data) ->
        # Extract flows from complex pattern handlers with guards
        extract_flows_from_complex_patterns(message_type, pattern_data, engine_name)

      {:complex_patterns, patterns} when is_list(patterns) ->
        # Handle list of pattern definitions
        patterns
        |> Enum.flat_map(fn pattern ->
          extract_flows_from_pattern_entry(message_type, pattern, engine_name)
        end)

      # Direct effect list (common in behavior definitions)
      effects when is_list(effects) ->
        extract_flows_from_effects(message_type, effects, engine_name)

      # Handle simple effect patterns (like :noop, :pong, etc.)
      effect when is_atom(effect) ->
        base_flow = %{
          source_engine: :client,
          target_engine: engine_name,
          message_type: message_type,
          payload_pattern: :any,
          conditions: [],
          effects: [effect],
          handler_type: :simple_effect
        }
        
        effect_flows = case effect do
          :pong ->
            # :pong effect typically means send pong back to sender
            [%{
              source_engine: engine_name,
              target_engine: :sender,
              message_type: :pong,
              payload_pattern: :pong,
              conditions: [],
              effects: [effect],
              handler_type: :inferred_response
            }]
          _ ->
            []
        end
        
        [base_flow] ++ effect_flows

      # Handle tuple effects like {:send, target, payload}
      {:ok, effects} when is_list(effects) ->
        # This is a common return pattern from handlers
        extract_flows_from_effects(message_type, effects, engine_name)

      {effect_type, target, payload} when effect_type in [:send, :spawn] ->
        [%{
          source_engine: engine_name,
          target_engine: resolve_target(target, engine_name),
          message_type: message_type,
          payload_pattern: payload,
          conditions: [],
          effects: [{effect_type, target, payload}],
          handler_type: :effect_tuple
        }]

      _ ->
        # For unrecognized handler types, create a basic flow
        [%{
          source_engine: :client,
          target_engine: engine_name,
          message_type: message_type,
          payload_pattern: :any,
          conditions: [],
          effects: [],
          handler_type: :unknown
        }]
    end
  end

  defp extract_flows_from_complex_patterns(message_type, pattern_data, engine_name) do
    # Handle complex patterns with guards and multiple cases
    base_flow = %{
      source_engine: :client,
      target_engine: engine_name,
      message_type: message_type,
      payload_pattern: Map.get(pattern_data, :payload_pattern, :any),
      conditions: Map.get(pattern_data, :guards, []),
      effects: [],
      handler_type: :complex_pattern
    }

    # Extract effects from the pattern data
    effects = extract_effects_from_pattern_data(pattern_data)
    
    if effects == [] do
      [base_flow]
    else
      # Create flows for each effect  
      effects
      |> Enum.map(fn effect ->
        case effect do
          {:send, target, payload} ->
            %{base_flow |
              source_engine: engine_name,
              target_engine: resolve_target(target, engine_name),
              payload_pattern: payload,
              effects: [effect]
            }
          
          {:spawn, target_engine, config, environment} ->
            %{base_flow |
              source_engine: engine_name,
              target_engine: target_engine,
              effects: [effect],
              metadata: %{spawn_config: config, spawn_env: environment}
            }
          
          _ ->
            nil
        end
      end)
      |> Enum.filter(&(&1 != nil))
    end
  end

  defp extract_flows_from_pattern_entry(message_type, pattern_entry, engine_name) do
    case pattern_entry do
      {_pattern, effects} when is_list(effects) ->
        # Pattern with direct effects list
        extract_flows_from_effects(message_type, effects, engine_name)
      
      {_pattern, {:ok, effects}} when is_list(effects) ->
        # Pattern returning {:ok, effects}
        extract_flows_from_effects(message_type, effects, engine_name)
      
      _ ->
        # Default flow for unrecognized pattern
        [%{
          source_engine: :client,
          target_engine: engine_name,
          message_type: message_type,
          payload_pattern: :any,
          conditions: [],
          effects: [],
          handler_type: :pattern
        }]
    end
  end

  defp extract_flows_from_effects(message_type, effects, engine_name) do
    # Start with a base flow showing the message is received
    base_flow = %{
      source_engine: :client,
      target_engine: engine_name,
      message_type: message_type,
      payload_pattern: :any,
      conditions: [],
      effects: effects,
      handler_type: :effects_list
    }

    # Extract communication effects from the effects list
    communication_flows = effects
    |> Enum.filter(fn
      {:send, _, _} -> true
      {:spawn, _, _, _} -> true
      {:spawn, _, _} -> true
      _ -> false
    end)
    |> Enum.map(fn effect ->
      case effect do
        {:send, target, payload} ->
          %{
            source_engine: engine_name,
            target_engine: resolve_target(target, engine_name),
            message_type: extract_message_type(payload),
            payload_pattern: payload,
            conditions: [],
            effects: [effect],
            handler_type: :send_effect
          }
        
        {:spawn, target_engine, config, environment} ->
          %{
            source_engine: engine_name,
            target_engine: target_engine,
            message_type: :spawn,
            payload_pattern: %{config: config, environment: environment},
            conditions: [],
            effects: [effect],
            handler_type: :spawn_effect
          }
          
        {:spawn, target_engine, config} ->
          %{
            source_engine: engine_name,
            target_engine: target_engine,
            message_type: :spawn,
            payload_pattern: %{config: config},
            conditions: [],
            effects: [effect],
            handler_type: :spawn_effect
          }
      end
    end)
    |> Enum.filter(&(&1 != nil))

    [base_flow] ++ communication_flows
  end

  defp extract_effects_from_pattern_data(pattern_data) when is_map(pattern_data) do
    # Look for effects in various possible locations in the pattern data
    cond do
      Map.has_key?(pattern_data, :effects) ->
        pattern_data.effects
      
      Map.has_key?(pattern_data, :handler) ->
        case pattern_data.handler do
          {:ok, effects} when is_list(effects) -> effects
          effects when is_list(effects) -> effects
          _ -> []
        end
      
      Map.has_key?(pattern_data, :actions) ->
        pattern_data.actions
      
      true ->
        []
    end
  end

  # Extract message type from payload for better diagram labeling
  defp extract_message_type(payload) do
    case payload do
      atom when is_atom(atom) -> atom
      {message_type, _} when is_atom(message_type) -> message_type
      %{} = map when map_size(map) > 0 ->
        # Try to find a type or tag field
        Map.get(map, :type, Map.get(map, :tag, :message))
      _ -> :message
    end
  end
  
  # Infer likely effects from function names for common patterns
  defp infer_effects_from_function_name(function_name, message_type, engine_name) do
    function_str = Atom.to_string(function_name)
    
    cond do
      String.contains?(function_str, "ping") and message_type == :ping ->
        [%{
          source_engine: engine_name,
          target_engine: :sender,
          message_type: :pong,
          payload_pattern: :pong,
          conditions: [],
          effects: [{:send, :sender, :pong}],
          handler_type: :inferred_response
        }]
      
      String.contains?(function_str, "echo") ->
        [%{
          source_engine: engine_name,
          target_engine: :sender,
          message_type: message_type,
          payload_pattern: :echo_response,
          conditions: [],
          effects: [{:send, :sender, :echo_response}],
          handler_type: :inferred_echo
        }]
      
      String.contains?(function_str, "forward") or String.contains?(function_str, "relay") ->
        [%{
          source_engine: engine_name,
          target_engine: :dynamic,
          message_type: :forwarded_message,
          payload_pattern: :dynamic,
          conditions: [],
          effects: [{:send, :dynamic, :forwarded_message}],
          handler_type: :inferred_forward
        }]
      
      true ->
        []
    end
  end

  defp resolve_target(target, _engine_name) do
    case target do
      :msg_sender_address -> :sender
      :sender -> :sender
      :client -> :client
      :dynamic -> :dynamic
      nil -> :unknown
      target when is_atom(target) -> target
      target when is_binary(target) -> String.to_atom(target)
      _ -> :dynamic
    end
  end

  defp filter_interaction_flows(flows, specs) do
    engine_names = Enum.map(specs, & &1.name)

    flows
    |> Enum.filter(fn flow ->
      # Include flows that show communication between different engines
      flow.target_engine in engine_names and flow.target_engine != flow.source_engine
    end)
  end

  defp generate_diagram_header(_spec, _options) do
    "sequenceDiagram"
  end

  defp generate_participants(flows, _spec) do
    # Extract unique participants from flows
    participants = flows
    |> Enum.flat_map(fn flow ->
      [flow.source_engine, flow.target_engine]
    end)
    |> Enum.uniq()
    |> Enum.filter(&(&1 != :client and &1 != :dynamic and &1 != :sender))  # These are handled specially

    # Add client as default participant
    all_participants = [:client | participants]

    # Generate participant declarations
    all_participants
    |> Enum.map(fn participant ->
      case participant do
        :client -> "    participant Client"
        engine_name -> "    participant #{engine_name} as #{format_engine_name(engine_name)}"
      end
    end)
    |> Enum.join("\n")
  end

  defp generate_message_sequences(flows) do
    flows
    |> Enum.flat_map(fn flow ->
      generate_sequences_for_flow(flow)
    end)
    |> Enum.join("\n")
  end

  defp generate_sequences_for_flow(flow) do
    sequences = []

    # Add the initial message flow
    initial_sequence = case flow.handler_type do
      :effects_list when flow.source_engine == :client ->
        # This is a message received by the engine from client
        "    #{format_participant_name(:client)}->>#{format_participant_name(flow.target_engine)}: #{format_message_type(flow.message_type)}"
      
      handler_type when handler_type in [:effect_tuple, :inferred_response] and flow.source_engine != :client ->
        # This is an effect sending a message from the engine
        source = format_participant_name(flow.source_engine)
        target = format_participant_name(flow.target_engine)
        "    #{source}->>#{target}: #{format_message_payload(flow.payload_pattern)}"
      
      _ when flow.source_engine == :client ->
        # Default: show client sending to engine
        "    #{format_participant_name(:client)}->>#{format_participant_name(flow.target_engine)}: #{format_message_type(flow.message_type)}"
      
      _ ->
        nil
    end

    sequences = if initial_sequence, do: [initial_sequence | sequences], else: sequences

    # Add note about handler type if it's interesting
    note_sequence = case flow.handler_type do
      :function ->
        metadata = Map.get(flow, :metadata, %{})
        if function = Map.get(metadata, :function) do
          "    Note over #{format_participant_name(flow.target_engine)}: Handled by #{function}/#{Map.get(metadata, :arity, "?")}"
        else
          nil
        end
      
      :complex_pattern when flow.conditions != [] ->
        "    Note over #{format_participant_name(flow.target_engine)}: With guards: #{inspect(flow.conditions)}"
      
      _ ->
        nil
    end

    sequences = if note_sequence, do: sequences ++ [note_sequence], else: sequences

    # Add effects as additional sequences
    # Skip effects for inferred_response flows since they're already represented
    effect_sequences = if flow.handler_type == :inferred_response do
      []
    else
      flow.effects
      |> Enum.map(fn effect ->
        generate_sequence_from_effect(effect, flow)
      end)
      |> Enum.filter(&(&1 != nil))
    end

    sequences ++ effect_sequences
  end

  defp generate_sequence_from_effect(effect, flow) do
    case effect do
      {:send, target, payload} ->
        source = format_participant_name(flow.target_engine)
        target_name = format_participant_name(resolve_target(target, flow.target_engine))
        message = format_message_payload(payload)
        "    #{source}->>#{target_name}: #{message}"

      {:spawn, engine_module, _config, _environment} ->
        source = format_participant_name(flow.target_engine)
        target_name = format_participant_name(engine_module)
        "    #{source}-->>#{target_name}: spawn #{format_engine_name(engine_module)}"
        
      {:update_environment, _new_env} ->
        # Show state update as a note
        "    Note over #{format_participant_name(flow.target_engine)}: State updated"

      :noop ->
        # Show noop as a self-note
        "    Note over #{format_participant_name(flow.target_engine)}: No operation"

      :pong ->
        # :pong effects are now handled by the proper flow extraction
        # This case is kept for legacy compatibility but returns nil
        nil

      atom when is_atom(atom) ->
        # Other atomic effects shown as notes
        "    Note over #{format_participant_name(flow.target_engine)}: Effect: #{atom}"

      _ ->
        nil
    end
  end

  defp format_message_payload(payload) do
    case payload do
      atom when is_atom(atom) -> ":#{atom}"
      {tag, data} when is_atom(tag) -> "{:#{tag}, #{inspect(data)}}"
      other -> inspect(other)
    end
  end

  defp generate_multi_engine_sequence_diagram(flows, specs, options) do
    # Generate diagram header
    header = "sequenceDiagram"

    # Generate participant declarations for all engines
    participants = generate_multi_engine_participants(specs)

    # Generate message sequences
    sequences = generate_message_sequences(flows)

    # Generate metadata if requested
    metadata = if options.include_metadata do
      generate_multi_engine_metadata_section(specs, options)
    else
      ""
    end

    # Combine all parts
    [header, participants, sequences, metadata]
    |> Enum.filter(&(&1 != ""))
    |> Enum.join("\n")
  end

  defp generate_multi_engine_participants(specs) do
    # Add client as default participant
    participants = [:client | Enum.map(specs, & &1.name)]

    participants
    |> Enum.map(fn participant ->
      case participant do
        :client -> "    participant Client"
        engine_name -> "    participant #{engine_name} as #{format_engine_name(engine_name)}"
      end
    end)
    |> Enum.join("\n")
  end

  defp format_engine_name(engine_name) do
    engine_name
    |> Atom.to_string()
    |> String.replace("Examples.", "")
    |> String.replace("Engine", "")
  end

  defp format_participant_name(participant) do
    case participant do
      :client -> "Client"
      :dynamic -> "Dynamic"
      :sender -> "Client"  # :sender typically refers back to the client
      engine_name -> "#{engine_name}"
    end
  end

  defp format_message_type(message_type) do
    case message_type do
      atom when is_atom(atom) -> ":#{atom}"
      other -> inspect(other)
    end
  end

  defp generate_file_path(spec, options) do
    filename = "#{options.file_prefix}#{format_engine_name(spec.name)}.md"
    Path.join(options.output_dir, filename)
  end

  defp generate_multi_engine_file_path(specs, options) do
    engine_names = specs
    |> Enum.map(&format_engine_name(&1.name))
    |> Enum.join("_")

    filename = "#{options.file_prefix}#{engine_names}_interaction.md"
    Path.join(options.output_dir, filename)
  end

  defp ensure_output_directory(output_dir) do
    File.mkdir_p!(output_dir)
  end

  defp write_diagram_file(file_path, mermaid_content, options) do
    # Create markdown content with Mermaid diagram
    markdown_content = """
    # #{extract_title_from_content(mermaid_content)}

    This diagram shows the communication flow for the engine(s).

    ```mermaid
    #{mermaid_content}
    ```

    #{if options.include_metadata do
      """
      ## Metadata

      - Generated at: #{DateTime.utc_now() |> DateTime.to_iso8601()}
      - Generated by: EngineSystem.Engine.DiagramGenerator
      """
    else
      ""
    end}
    """

    File.write!(file_path, markdown_content)
  end

  defp extract_title_from_content(_mermaid_content) do
    # Extract a title from the Mermaid content
    # This is a simple implementation - could be enhanced
    "Engine Communication Diagram"
  end

  defp generate_metadata_section(spec, _options) do
    # Add metadata as comments in the Mermaid diagram
    """

    Note over Client, #{spec.name}: Generated at #{DateTime.utc_now() |> DateTime.to_iso8601()}
    """
  end

  defp generate_multi_engine_metadata_section(specs, _options) do
    engine_names = specs |> Enum.map(& &1.name) |> Enum.join(", ")
    """

    Note over Client, #{List.last(specs).name}: Generated at #{DateTime.utc_now() |> DateTime.to_iso8601()}
    Note over Client, #{List.last(specs).name}: Engines: #{engine_names}
    """
  end

  # Get all registered engine specs from the system registry
  defp get_all_registered_specs do
    try do
      # Attempt to get registered specs from the registry
      case EngineSystem.System.Registry.list_specs() do
        specs when is_list(specs) -> specs
        _ -> []
      end
    rescue
      # Registry might not be available at compile time
      _ -> []
    catch
      # System not running
      :exit, _ -> []
    end
  end

  @doc """
  I generate diagrams for all engines that have the generate_diagrams option enabled.
  
  This function is called automatically during compilation for engines with
  `generate_diagrams: true` in their defengine declaration.
  """
  @spec generate_compilation_diagrams() :: :ok
  def generate_compilation_diagrams do
    try do
      specs = get_all_registered_specs()
      
      # Generate individual engine diagrams
      specs
      |> Enum.each(fn spec ->
        case generate_diagram(spec) do
          {:ok, file_path} ->
            IO.puts("📊 Generated diagram: #{file_path}")
          
          {:error, reason} ->
            IO.warn("Failed to generate diagram for #{spec.name}: #{inspect(reason)}")
        end
      end)
      
      # Generate system overview diagram if we have multiple engines
      if length(specs) > 1 do
        case generate_system_diagram() do
          {:ok, file_path} ->
            IO.puts("🗺️  Generated system diagram: #{file_path}")
          
          {:error, reason} ->
            IO.warn("Failed to generate system diagram: #{inspect(reason)}")
        end
      end
      
      :ok
    rescue
      error ->
        IO.warn("Error during compilation diagram generation: #{inspect(error)}")
        :ok
    end
  end

  ## Runtime Refinement Functions

  @doc """
  I enrich compile-time message flows with runtime telemetry data.
  """
  @spec enrich_flows_with_runtime_data([message_flow()], [RuntimeFlowTracker.flow_summary()]) :: [runtime_enriched_flow()]
  defp enrich_flows_with_runtime_data(compile_flows, runtime_flows) do
    Enum.map(compile_flows, fn flow ->
      # Find matching runtime data
      runtime_data = find_matching_runtime_flow(flow, runtime_flows)
      
      Map.put(flow, :runtime_data, runtime_data)
    end)
  end

  defp find_matching_runtime_flow(compile_flow, runtime_flows) do
    Enum.find_value(runtime_flows, fn runtime_flow ->
      if flows_match?(compile_flow, runtime_flow) do
        %{
          total_count: runtime_flow.total_count,
          success_rate: if runtime_flow.total_count > 0 do
            runtime_flow.success_count / runtime_flow.total_count * 100
          else
            0.0
          end,
          avg_duration_ms: runtime_flow.avg_duration_ms,
          frequency_per_minute: runtime_flow.frequency_per_minute,
          first_seen: runtime_flow.first_seen,
          last_seen: runtime_flow.last_seen
        }
      end
    end)
  end

  defp flows_match?(compile_flow, runtime_flow) do
    # Normalize and match flows by source, target, and message type
    sources_match = normalize_participant_for_matching(compile_flow.source_engine) == 
                   normalize_participant_for_matching(runtime_flow.source_engine)
    
    targets_match = normalize_participant_for_matching(compile_flow.target_engine) == 
                   normalize_participant_for_matching(runtime_flow.target_engine)
    
    messages_match = compile_flow.message_type == runtime_flow.message_type
    
    sources_match and targets_match and messages_match
  end

  defp normalize_participant_for_matching(participant) do
    case participant do
      # Client address variations
      :client -> :client
      {0, 0} -> :client
      nil -> :client
      
      # Sender variations  
      :sender -> :client  # :sender typically refers back to client
      
      # Engine addresses - we need to resolve these by looking up the registry
      {_node, _id} = address -> 
        # Try to resolve address to engine name
        case EngineSystem.System.Registry.lookup_instance(address) do
          {:ok, %{spec_key: {engine_module, _version}}} -> engine_module
          _ -> address  # Fallback to address if lookup fails
        end
      
      # Engine names
      engine_name when is_atom(engine_name) -> engine_name
      
      # Everything else
      other -> other
    end
  end

  @doc """
  I generate a runtime-enriched Mermaid sequence diagram.
  """
  @spec generate_runtime_enriched_sequence_diagram([runtime_enriched_flow()], Spec.t(), generation_options()) :: String.t()
  defp generate_runtime_enriched_sequence_diagram(enriched_flows, spec, options) do
    # Generate diagram header
    header = generate_diagram_header(spec, options)

    # Generate participant declarations
    participants = generate_participants(enriched_flows, spec)

    # Generate message sequences with runtime data
    sequences = generate_runtime_message_sequences(enriched_flows)

    # Generate runtime metadata section
    metadata = if options.include_metadata do
      generate_runtime_metadata_section(enriched_flows, spec, options)
    else
      ""
    end

    # Combine all parts
    [header, participants, sequences, metadata]
    |> Enum.filter(&(&1 != ""))
    |> Enum.join("\n")
  end

  defp generate_runtime_message_sequences(enriched_flows) do
    enriched_flows
    |> Enum.flat_map(fn flow ->
      generate_runtime_sequences_for_flow(flow)
    end)
    |> Enum.join("\n")
  end

  defp generate_runtime_sequences_for_flow(flow) do
    sequences = []

    # Generate the basic message sequence
    basic_sequence = case flow.handler_type do
      :effects_list when flow.source_engine == :client ->
        source = format_participant_name(:client)
        target = format_participant_name(flow.target_engine)
        message = format_message_with_runtime_data(flow.message_type, flow.runtime_data)
        "    #{source}->>#{target}: #{message}"
      
      _ when flow.source_engine == :client ->
        source = format_participant_name(:client)
        target = format_participant_name(flow.target_engine)
        message = format_message_with_runtime_data(flow.message_type, flow.runtime_data)
        "    #{source}->>#{target}: #{message}"
      
      _ ->
        nil
    end

    sequences = if basic_sequence, do: [basic_sequence | sequences], else: sequences

    # Add runtime statistics as notes
    if flow.runtime_data do
      runtime_note = generate_runtime_note(flow)
      sequences = sequences ++ [runtime_note]
    end

    sequences
  end

  defp format_message_with_runtime_data(message_type, runtime_data) do
    base_message = format_message_type(message_type)
    
    if runtime_data do
      # Add runtime indicators
      frequency_indicator = cond do
        runtime_data.frequency_per_minute > 10 -> "🔥"  # Hot path
        runtime_data.frequency_per_minute > 1 -> "⚡"   # Active
        true -> ""                                       # Occasional
      end
      
      success_indicator = if runtime_data.success_rate < 95 do
        "⚠️"  # Low success rate
      else
        ""
      end

      "#{base_message} #{frequency_indicator}#{success_indicator}"
    else
      "#{base_message} (📋)"  # Compile-time only
    end
  end

  defp generate_runtime_note(flow) do
    if flow.runtime_data do
      target = format_participant_name(flow.target_engine)
      count = flow.runtime_data.total_count
      success_rate = safe_round(flow.runtime_data.success_rate, 1)
      
      duration_info = if flow.runtime_data.avg_duration_ms do
        ", #{safe_round(flow.runtime_data.avg_duration_ms, 1)}ms avg"
      else
        ""
      end
      
      "    Note over #{target}: #{count} calls, #{success_rate}% success#{duration_info}"
    else
      target = format_participant_name(flow.target_engine)
      "    Note over #{target}: (Compile-time spec only)"
    end
  end

  defp safe_round(nil, _precision), do: "0.0"
  defp safe_round(value, precision) when is_integer(value) do
    Float.round(value * 1.0, precision)
  end
  defp safe_round(value, precision) when is_float(value) do
    Float.round(value, precision)
  end
  defp safe_round(value, _precision), do: inspect(value)

  defp generate_runtime_metadata_section(enriched_flows, spec, _options) do
    runtime_flows_count = Enum.count(enriched_flows, & &1.runtime_data)
    compile_only_count = Enum.count(enriched_flows, &is_nil(&1.runtime_data))
    
    total_messages = enriched_flows
    |> Enum.filter(& &1.runtime_data)
    |> Enum.map(& &1.runtime_data.total_count)
    |> Enum.sum()

    """

    Note over Client, #{spec.name}: 📊 Runtime Data Summary
    Note over Client, #{spec.name}: #{runtime_flows_count} active flows, #{compile_only_count} spec-only
    Note over Client, #{spec.name}: #{total_messages} total messages processed
    Note over Client, #{spec.name}: Generated at #{DateTime.utc_now() |> DateTime.to_iso8601()}
    """
  end

  defp generate_runtime_file_path(spec, options) do
    filename = "#{options.file_prefix}#{format_engine_name(spec.name)}_runtime.md"
    Path.join(options.output_dir, filename)
  end
end
