#!/usr/bin/env elixir

# Load the necessary files
Code.require_file("diagram_demo.ex", __DIR__)
Code.require_file("relay_engine.ex", __DIR__)
Code.require_file("diagram_generation_demo.ex", __DIR__)

# Run the demonstration
IO.puts("🎯 Loading Mermaid Diagram Generation Demo...")

# First verify the setup
Examples.DiagramGenerationDemo.verify_demo_setup()

# Run the full demonstration
Examples.DiagramGenerationDemo.run_full_demo()
