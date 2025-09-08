defmodule Examples.RuntimeDiagramDemo do
  @moduledoc """
  I demonstrate runtime-refined diagram generation.

  This module shows how to:
  1. Start runtime flow tracking
  2. Execute engine interactions to generate telemetry data
  3. Generate runtime-refined diagrams that show actual usage patterns

  ## Usage

      # Start the demo
      Examples.RuntimeDiagramDemo.run_demo()

      # This will:
      # - Start flow tracking
      # - Spawn engines and send messages
      # - Generate both compile-time and runtime-refined diagrams
      # - Show the differences between spec-based and actual flows
  """

  alias EngineSystem.Engine.{DiagramGenerator, RuntimeFlowTracker}
  alias EngineSystem.API

  @doc """
  Run the complete runtime diagram generation demo.
  """
  def run_demo do
    IO.puts("🚀 Starting Runtime Diagram Generation Demo")
    IO.puts("=" |> String.duplicate(50))

    # Step 1: Start runtime flow tracking
    IO.puts("📊 Step 1: Starting runtime flow tracking...")
    start_tracking()

    # Step 2: Generate compile-time diagrams for reference
    IO.puts("📋 Step 2: Generating compile-time diagrams...")
    generate_baseline_diagrams()

    # Step 3: Execute engine interactions to create runtime data
    IO.puts("⚡ Step 3: Executing engine interactions...")
    execute_demo_interactions()

    # Step 4: Generate runtime-refined diagrams
    IO.puts("🔥 Step 4: Generating runtime-refined diagrams...")
    generate_runtime_diagrams()

    # Step 5: Show statistics
    IO.puts("📈 Step 5: Runtime statistics...")
    show_statistics()

    IO.puts("✅ Demo completed! Check docs/diagrams/ for generated files")
  end

  @doc """
  Start runtime flow tracking.
  """
  def start_tracking do
    # Start the runtime flow tracker
    case GenServer.start_link(RuntimeFlowTracker, [], name: RuntimeFlowTracker) do
      {:ok, _pid} -> 
        IO.puts("✅ RuntimeFlowTracker started")
        RuntimeFlowTracker.start_tracking()
        IO.puts("✅ Flow tracking enabled")
      
      {:error, {:already_started, _pid}} ->
        IO.puts("ℹ️  RuntimeFlowTracker already running")
        RuntimeFlowTracker.start_tracking()
        RuntimeFlowTracker.clear_data()  # Clear previous data
        IO.puts("✅ Flow tracking enabled, data cleared")
    end
  end

  @doc """
  Generate baseline compile-time diagrams.
  """
  def generate_baseline_diagrams do
    try do
      # Generate diagram for DiagramDemoEngine
      demo_spec = Examples.DiagramDemoEngine.__engine_spec__()
      case DiagramGenerator.generate_diagram(demo_spec, "docs/diagrams", %{file_prefix: "baseline_"}) do
        {:ok, file_path} ->
          IO.puts("✅ Generated baseline diagram: #{file_path}")
        {:error, reason} ->
          IO.puts("❌ Failed to generate baseline diagram: #{inspect(reason)}")
      end
    rescue
      error ->
        IO.puts("❌ Error generating baseline diagrams: #{inspect(error)}")
    end
  end

  @doc """
  Execute various engine interactions to create runtime telemetry data.
  """
  def execute_demo_interactions do
    IO.puts("🎯 Spawning demo engines...")

    # Spawn demo engine
    case API.spawn_engine(Examples.DiagramDemoEngine) do
      {:ok, demo_address} ->
        IO.puts("✅ Spawned DiagramDemoEngine at #{inspect(demo_address)}")
        
        # Execute various message patterns
        simulate_message_patterns(demo_address)

      {:error, reason} ->
        IO.puts("❌ Failed to spawn DiagramDemoEngine: #{inspect(reason)}")
    end
  end

  defp simulate_message_patterns(demo_address) do
    IO.puts("📨 Simulating message patterns...")

    # Pattern 1: High-frequency ping-pong (hot path)
    IO.puts("🏓 Simulating high-frequency ping-pong...")
    Enum.each(1..25, fn i ->
      API.send_message(demo_address, {:ping, %{}})
      if rem(i, 5) == 0, do: Process.sleep(10)  # Brief pause every 5 messages
    end)

    # Pattern 2: Counter increments (medium frequency)
    IO.puts("📊 Simulating counter operations...")
    Enum.each(1..10, fn _i ->
      API.send_message(demo_address, {:increment, %{}})
      Process.sleep(50)
    end)

    # Pattern 3: Status queries (low frequency)
    IO.puts("❓ Simulating status queries...")
    Enum.each(1..3, fn _i ->
      API.send_message(demo_address, {:status, %{}})
      Process.sleep(100)
    end)

    # Pattern 4: Some broadcast operations
    IO.puts("📡 Simulating broadcast operations...")
    API.send_message(demo_address, {:set_targets, %{targets: [:engine1, :engine2]}})
    Process.sleep(50)
    
    Enum.each(1..5, fn _i ->
      API.send_message(demo_address, {:broadcast, %{message: {:test_broadcast, %{data: "test"}}}})
      Process.sleep(100)
    end)

    # Pattern 5: Reset operation (very rare)
    IO.puts("🔄 Simulating reset operation...")
    API.send_message(demo_address, {:reset, %{}})
    
    # Allow some time for message processing
    Process.sleep(500)
    
    IO.puts("✅ Message simulation completed")
  end

  @doc """
  Generate runtime-refined diagrams using collected telemetry data.
  """
  def generate_runtime_diagrams do
    try do
      # Generate runtime-refined diagram for DiagramDemoEngine
      demo_spec = Examples.DiagramDemoEngine.__engine_spec__()
      case DiagramGenerator.generate_runtime_refined_diagram(demo_spec, "docs/diagrams") do
        {:ok, file_path} ->
          IO.puts("✅ Generated runtime-refined diagram: #{file_path}")
        {:error, reason} ->
          IO.puts("❌ Failed to generate runtime-refined diagram: #{inspect(reason)}")
      end
    rescue
      error ->
        IO.puts("❌ Error generating runtime diagrams: #{inspect(error)}")
    end
  end

  @doc """
  Show runtime statistics and analysis.
  """
  def show_statistics do
    stats = RuntimeFlowTracker.get_stats()
    flow_data = RuntimeFlowTracker.get_flow_data()

    IO.puts("📊 Runtime Flow Statistics")
    IO.puts("-" |> String.duplicate(30))
    IO.puts("Total Events: #{stats.total_events}")
    IO.puts("Unique Flows: #{stats.total_flows}")
    IO.puts("Runtime: #{Float.round(stats.runtime_minutes, 2)} minutes")
    IO.puts("Events/min: #{Float.round(stats.events_per_minute, 1)}")
    
    IO.puts("\n🔍 Flow Analysis:")
    flow_data
    |> Enum.sort_by(& &1.total_count, :desc)
    |> Enum.take(10)  # Top 10 flows
    |> Enum.each(fn flow ->
      success_rate = safe_round(flow.success_count / flow.total_count * 100, 1)
      frequency = safe_round(flow.frequency_per_minute, 2)
      
      duration_info = if flow.avg_duration_ms do
        " (#{safe_round(flow.avg_duration_ms, 1)}ms avg)"
      else
        ""
      end
      
      IO.puts("  #{flow.message_type}: #{flow.total_count} calls, #{success_rate}% success, #{frequency}/min#{duration_info}")
    end)

    # Show comparison with compile-time expectations
    IO.puts("\n📋 Compile-time vs Runtime Comparison:")
    demo_spec = Examples.DiagramDemoEngine.__engine_spec__()
    compile_flows = DiagramGenerator.analyze_message_flows(demo_spec)
    
    compile_flow_types = Enum.map(compile_flows, & &1.message_type) |> Enum.uniq()
    runtime_flow_types = Enum.map(flow_data, & &1.message_type) |> Enum.uniq()
    
    unused_flows = compile_flow_types -- runtime_flow_types
    unexpected_flows = runtime_flow_types -- compile_flow_types
    
    if unused_flows != [] do
      IO.puts("  📋 Unused flows (compile-time only): #{inspect(unused_flows)}")
    end
    
    if unexpected_flows != [] do
      IO.puts("  ⚡ Unexpected flows (runtime only): #{inspect(unexpected_flows)}")
    end
    
    active_flows = compile_flow_types -- unused_flows
    IO.puts("  ✅ Active flows: #{inspect(active_flows)}")
  end

  @doc """
  Stop flow tracking and cleanup.
  """
  def stop_tracking do
    RuntimeFlowTracker.stop_tracking()
    IO.puts("🛑 Flow tracking stopped")
  end

  @doc """
  Generate a comparison report showing differences between compile-time and runtime patterns.
  """
  def generate_comparison_report do
    IO.puts("📊 Generating Comparison Report")
    IO.puts("=" |> String.duplicate(40))

    demo_spec = Examples.DiagramDemoEngine.__engine_spec__()
    compile_flows = DiagramGenerator.analyze_message_flows(demo_spec)
    runtime_flows = RuntimeFlowTracker.get_flow_data()

    report = %{
      compile_time: %{
        total_flows: length(compile_flows),
        flow_types: Enum.map(compile_flows, & &1.message_type) |> Enum.uniq(),
        handlers: Enum.map(compile_flows, & &1.handler_type) |> Enum.uniq()
      },
      runtime: %{
        total_flows: length(runtime_flows),
        flow_types: Enum.map(runtime_flows, & &1.message_type) |> Enum.uniq(),
        total_messages: Enum.map(runtime_flows, & &1.total_count) |> Enum.sum(),
        avg_success_rate: calculate_average_success_rate(runtime_flows)
      },
      analysis: %{
        spec_coverage: calculate_spec_coverage(compile_flows, runtime_flows),
        hot_paths: identify_hot_paths(runtime_flows),
        error_patterns: identify_error_patterns(runtime_flows)
      }
    }

    display_comparison_report(report)
    report
  end

  # Helper function for safe float rounding
  defp safe_round(nil, _precision), do: "0.0"
  defp safe_round(value, precision) when is_integer(value) do
    Float.round(value * 1.0, precision)
  end
  defp safe_round(value, precision) when is_float(value) do
    Float.round(value, precision)
  end
  defp safe_round(value, _precision), do: inspect(value)

  defp calculate_average_success_rate(runtime_flows) do
    if length(runtime_flows) > 0 do
      total_calls = Enum.map(runtime_flows, & &1.total_count) |> Enum.sum()
      total_successes = Enum.map(runtime_flows, & &1.success_count) |> Enum.sum()
      
      if total_calls > 0 do
        Float.round(total_successes / total_calls * 100, 2)
      else
        0.0
      end
    else
      0.0
    end
  end

  defp calculate_spec_coverage(compile_flows, runtime_flows) do
    compile_types = Enum.map(compile_flows, & &1.message_type) |> MapSet.new()
    runtime_types = Enum.map(runtime_flows, & &1.message_type) |> MapSet.new()
    
    covered = MapSet.intersection(compile_types, runtime_types) |> MapSet.size()
    total = MapSet.size(compile_types)
    
    if total > 0 do
      Float.round(covered / total * 100, 2)
    else
      0.0
    end
  end

  defp identify_hot_paths(runtime_flows) do
    runtime_flows
    |> Enum.filter(& &1.frequency_per_minute > 1.0)
    |> Enum.sort_by(& &1.frequency_per_minute, :desc)
    |> Enum.map(& &1.message_type)
  end

  defp identify_error_patterns(runtime_flows) do
    runtime_flows
    |> Enum.filter(fn flow ->
      success_rate = if flow.total_count > 0 do
        flow.success_count / flow.total_count * 100
      else
        100
      end
      success_rate < 95
    end)
    |> Enum.map(& %{
      message_type: &1.message_type,
      success_rate: Float.round(&1.success_count / &1.total_count * 100, 2),
      failure_count: &1.failure_count
    })
  end

  defp display_comparison_report(report) do
    IO.puts("Compile-time Analysis:")
    IO.puts("  Total Flows: #{report.compile_time.total_flows}")
    IO.puts("  Flow Types: #{inspect(report.compile_time.flow_types)}")
    IO.puts("  Handler Types: #{inspect(report.compile_time.handlers)}")

    IO.puts("\nRuntime Analysis:")
    IO.puts("  Total Flows: #{report.runtime.total_flows}")
    IO.puts("  Flow Types: #{inspect(report.runtime.flow_types)}")
    IO.puts("  Total Messages: #{report.runtime.total_messages}")
    IO.puts("  Avg Success Rate: #{report.runtime.avg_success_rate}%")

    IO.puts("\nAnalysis:")
    IO.puts("  Spec Coverage: #{report.analysis.spec_coverage}%")
    IO.puts("  Hot Paths: #{inspect(report.analysis.hot_paths)}")
    
    if report.analysis.error_patterns != [] do
      IO.puts("  Error Patterns:")
      Enum.each(report.analysis.error_patterns, fn pattern ->
        IO.puts("    #{pattern.message_type}: #{pattern.success_rate}% success (#{pattern.failure_count} failures)")
      end)
    else
      IO.puts("  Error Patterns: None detected")
    end
  end
end