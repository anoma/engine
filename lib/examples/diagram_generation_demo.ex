defmodule Examples.DiagramGenerationDemo do
  @moduledoc """
  Comprehensive demonstration of the Mermaid diagram generation feature.

  This module provides functions to test and demonstrate the automatic
  generation of Mermaid sequence diagrams from engine specifications.

  ## Features Demonstrated

  1. **Single Engine Diagrams**: Individual communication patterns
  2. **Multi-Engine Diagrams**: Inter-engine communication flows
  3. **Message Flow Analysis**: Detailed flow extraction and analysis
  4. **Various Handler Types**: Function, complex patterns, effects
  5. **Error Handling**: Graceful handling of generation failures

  ## Usage

      # Run all demonstrations
      Examples.DiagramGenerationDemo.run_full_demo()
      # Generate individual diagrams
      Examples.DiagramGenerationDemo.generate_demo_diagrams()
      # Analyze message flows
      Examples.DiagramGenerationDemo.analyze_engine_flows()
      # Test multi-engine interactions
      Examples.DiagramGenerationDemo.test_multi_engine_diagram()
  """

  alias EngineSystem.Engine.DiagramGenerator
  alias Examples.{DiagramDemoEngine, RelayEngine}
  require Logger

  @demo_output_dir "docs/diagrams/demo"

  def run_full_demo do
    IO.puts("""

    🚀 Starting Mermaid Diagram Generation Demonstration
    ====================================================

    This demo will showcase the automatic generation of Mermaid sequence
    diagrams from EngineSystem engine specifications.

    """)

    # Ensure output directory exists
    ensure_demo_directory()

    # Run demonstrations
    analyze_engine_flows()
    generate_demo_diagrams()
    test_multi_engine_diagram()
    demonstrate_system_diagram()

    IO.puts("""

    ✨ Demonstration Complete!
    =========================

    Check the generated diagrams in: #{@demo_output_dir}/

    Files generated:
    - DiagramDemo.md (individual engine diagram)
    - RelayEngine.md (relay engine diagram)
    - demo_interaction.md (multi-engine interaction)
    - system_overview.md (complete system diagram)

    Open these files in a Markdown viewer or Mermaid-compatible editor
    to see the visual sequence diagrams.

    """)
  end

  def analyze_engine_flows do
    IO.puts("\n🔍 Step 1: Analyzing Message Flows")
    IO.puts("=" <> String.duplicate("=", 33))

    engines = [
      {DiagramDemoEngine, "DiagramDemo"},
      {RelayEngine, "Relay"}
    ]

    Enum.each(engines, &analyze_engine_flows_for/1)
  end

  defp analyze_engine_flows_for({engine_module, name}) do
    IO.puts("\n📊 #{name} Engine Message Flows:")

    spec = engine_module.__engine_spec__()
    flows = DiagramGenerator.analyze_message_flows(spec)

    display_flows(flows)
  end

  defp display_flows([]) do
    IO.puts("  ⚠️  No message flows detected")
  end

  defp display_flows(flows) do
    flows
    |> Enum.with_index(1)
    |> Enum.each(&display_flow/1)
  end

  defp display_flow({flow, index}) do
    source = format_participant(flow.source_engine)
    target = format_participant(flow.target_engine)

    IO.puts("  #{index}. #{source} → #{target} : #{flow.message_type}")
    IO.puts("     Type: #{flow.handler_type}, Effects: #{length(flow.effects)}")

    display_effects(flow.effects)
  end

  defp display_effects([]), do: :ok

  defp display_effects(effects) do
    effects
    |> Enum.take(2)
    |> Enum.each(fn effect ->
      IO.puts("     └─ #{format_effect(effect)}")
    end)

    if length(effects) > 2 do
      IO.puts("     └─ ... and #{length(effects) - 2} more")
    end
  end

  def generate_demo_diagrams do
    IO.puts("\n📈 Step 2: Generating Individual Engine Diagrams")
    IO.puts("=" <> String.duplicate("=", 45))

    engines = [
      DiagramDemoEngine,
      RelayEngine
    ]

    engines
    |> Enum.each(fn engine_module ->
      spec = engine_module.__engine_spec__()

      IO.puts("\n🎨 Generating diagram for #{spec.name}...")

      diagram_options = %{
        output_dir: @demo_output_dir,
        include_metadata: true,
        diagram_title: "#{spec.name} Communication Patterns",
        file_prefix: ""
      }

      case DiagramGenerator.generate_diagram(spec, nil, diagram_options) do
        {:ok, file_path} ->
          IO.puts("  ✅ Generated: #{file_path}")

          # Show a preview of the generated content
          if File.exists?(file_path) do
            content = File.read!(file_path)
            preview = content |> String.split("\n") |> Enum.take(10) |> Enum.join("\n")
            IO.puts("  📄 Preview:")
            IO.puts(String.replace(preview, "\n", "\n     "))
            IO.puts("     ... (truncated)")
          end

        {:error, reason} ->
          IO.puts("  ❌ Failed: #{inspect(reason)}")
      end
    end)
  end

  def test_multi_engine_diagram do
    IO.puts("\n🔗 Step 3: Testing Multi-Engine Interaction Diagram")
    IO.puts("=" <> String.duplicate("=", 49))

    specs = [
      DiagramDemoEngine.__engine_spec__(),
      RelayEngine.__engine_spec__()
    ]

    IO.puts("\n🌐 Generating multi-engine interaction diagram...")
    IO.puts("   Engines: #{Enum.map_join(specs, ", ", & &1.name)}")

    diagram_options = %{
      output_dir: @demo_output_dir,
      include_metadata: true,
      diagram_title: "Demo Engines Interaction",
      file_prefix: "demo_"
    }

    case DiagramGenerator.generate_multi_engine_diagram(specs, nil, diagram_options) do
      {:ok, file_path} ->
        IO.puts("  ✅ Generated interaction diagram: #{file_path}")

        # Analyze the interaction flows
        all_flows = specs |> Enum.flat_map(&DiagramGenerator.analyze_message_flows/1)

        interaction_count =
          all_flows
          |> Enum.count(fn flow ->
            flow.target_engine != flow.source_engine and
              flow.target_engine != :client and
              flow.source_engine != :client
          end)

        IO.puts("  📊 Found #{interaction_count} inter-engine interactions")

      {:error, reason} ->
        IO.puts("  ❌ Failed: #{inspect(reason)}")
    end
  end

  def demonstrate_system_diagram do
    IO.puts("\n🗺️  Step 4: Demonstrating System-Wide Diagram")
    IO.puts("=" <> String.duplicate("=", 41))

    IO.puts("\n🏗️  Generating complete system diagram...")

    diagram_options = %{
      output_dir: @demo_output_dir,
      include_metadata: true,
      diagram_title: "Complete Engine System Overview",
      file_prefix: "system_"
    }

    case DiagramGenerator.generate_system_diagram(nil, diagram_options) do
      {:ok, file_path} ->
        IO.puts("  ✅ Generated system diagram: #{file_path}")

      {:error, :no_engines_registered} ->
        IO.puts("  ⚠️  No engines registered in system registry")
        IO.puts("  💡 This is expected during compile-time testing")

      {:error, reason} ->
        IO.puts("  ❌ Failed: #{inspect(reason)}")
    end
  end

  # Helper function to verify the demonstration setup
  def verify_demo_setup do
    IO.puts("\n🔧 Verifying Demo Setup")
    IO.puts("=" <> String.duplicate("=", 23))

    engines_to_check = [
      DiagramDemoEngine,
      RelayEngine
    ]

    engines_to_check
    |> Enum.each(fn engine_module ->
      try do
        spec = engine_module.__engine_spec__()
        IO.puts("✅ #{spec.name} - version #{spec.version}")
        IO.puts("   Interface: #{length(spec.interface)} messages")
        IO.puts("   Behaviours: #{length(spec.behaviour_rules)} rules")
      rescue
        error ->
          IO.puts("❌ #{engine_module} - #{inspect(error)}")
      end
    end)

    # Check output directory
    if File.exists?(@demo_output_dir) do
      IO.puts("✅ Output directory exists: #{@demo_output_dir}")
    else
      IO.puts("⚠️  Output directory will be created: #{@demo_output_dir}")
    end
  end

  # Utility Functions

  defp ensure_demo_directory do
    File.mkdir_p!(@demo_output_dir)
  end

  defp format_participant(participant) do
    case participant do
      :client -> "Client"
      :sender -> "Sender"
      :dynamic -> "Dynamic"
      atom when is_atom(atom) -> Atom.to_string(atom) |> String.replace("Examples.", "")
      other -> inspect(other)
    end
  end

  defp format_effect(effect) do
    case effect do
      {:send, target, payload} ->
        "send #{inspect(payload)} to #{format_participant(target)}"

      {:spawn, engine, _, _} ->
        "spawn #{format_participant(engine)}"

      {:update_environment, _} ->
        "update environment"

      atom when is_atom(atom) ->
        to_string(atom)

      other ->
        inspect(other)
    end
  end
end
