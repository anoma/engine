defmodule EngineSystem.MixProject do
  use Mix.Project

  def project do
    [
      name: "EngineSystem",
      app: :engine_system,
      version: "0.1.0",
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      source_url: "https://github.com/anoma/engine",
      homepage_url: "https://anoma.github.io/engine/",
      deps: deps(),
      docs: docs(),
      description: "A formal model-adherent implementation of the Engine System",
      package: package(),
      dialyzer: [
        plt_add_apps: [:mix],
        flags: [:error_handling, :underspecs],
        ignore_warnings: ".dialyzer_ignore.exs"
      ]
    ]
  end

  defp package do
    [
      name: "engine",
      organization: "Anoma",
      licenses: ["MIT"],
      maintainers: ["Anoma"],
      description: "A formal model-adherent implementation of the Engine System",
      links: %{
        "GitHub" => "https://github.com/anoma/engine",
        "Documentation" => "https://anoma.github.io/engine/"
      },
      files: ~w(lib .formatter.exs mix.exs README.livemd LICENSE CHANGELOG.md)
    ]
  end

  defp elixirc_paths(_), do: ["lib", "examples", "test"]

  def application do
    [
      extra_applications: [:logger, :parsetools],
      mod: {EngineSystem.Application, []}
    ]
  end

  defp deps do
    [
      {:typed_struct, "~> 0.3.0"},
      {:uuid, "~> 1.1.8"},
      {:gen_stage, "~> 1.2.1"},
      {:telemetry, "~> 1.0"},
      {:ex_doc, "~> 0.38.0", only: :dev, runtime: false},
      {:credo, "~> 1.7.12", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4.5", only: [:dev, :test], runtime: false}
    ]
  end

  defp docs do
    [
      # Main configuration
      main: "readme",
      name: "EngineSystem",
      source_ref: "main",
      source_url: "https://github.com/anoma/engine",

      # Assets and styling (fixed format)
      assets: %{"assets" => "assets"},

      # Additional pages including the Livebook tutorial
      extras: [
        "README.livemd",
        "CHANGELOG.md": [title: "Changelog"],
        LICENSE: [title: "License"]
      ],

      # Navigation structure
      # groups_for_extras: [
      #   "Getting Started": ["README.livemd"],
      #   "Project Info": ["CHANGELOG.md", "LICENSE"]
      # ],

      # Reorganized module grouping for better API reference organization
      groups_for_modules: [
        # Primary entry points - what users interact with first
        "Primary API": [
          EngineSystem,
          EngineSystem.API,
          EngineSystem.Lifecycle
        ],
        "System Management": [
          EngineSystem.System.Registry,
          EngineSystem.System.Spawner,
          EngineSystem.System.Spawner.Logger,
          EngineSystem.System.Spawner.Validator,
          EngineSystem.System.Services,
          EngineSystem.System.Utilities
        ],

        # Engine Definition and DSL - the core of defining engines
        "Engine Definition (DSL)": [
          EngineSystem.Engine.DSL,
          EngineSystem.Engine.DSL.InterfaceBuilder,
          EngineSystem.Engine.DSL.ConfigBuilder,
          EngineSystem.Engine.DSL.EnvironmentBuilder,
          EngineSystem.Engine.DSL.BehaviorBuilder,
          EngineSystem.Engine.DSL.Validation,
          EngineSystem.Engine.DSL.Utils
        ],

        # Core Engine Architecture - fundamental engine structures
        "Core Engine Architecture": [
          EngineSystem.Engine,
          EngineSystem.Engine.Spec,
          EngineSystem.Engine.State,
          EngineSystem.Engine.State.Configuration,
          EngineSystem.Engine.State.Environment,
          EngineSystem.Engine.State.Status,
          EngineSystem.Engine.Instance,
          EngineSystem.Engine.Behaviour
        ],

        # Engine Effects - actions engines can perform
        "Engine Effects": [
          EngineSystem.Engine.Effect,
          EngineSystem.Engine.Effects.MessageEffects,
          EngineSystem.Engine.Effects.StateEffects,
          EngineSystem.Engine.Effects.SystemEffects
        ],

        # Mailbox System - mailbox-as-actors implementation
        "Mailbox System": [
          EngineSystem.Mailbox.Behaviour,
          EngineSystem.Mailbox.MailboxRuntime,
          EngineSystem.Mailbox.DefaultMailboxEngine
        ],

        # System Infrastructure - internal system management
        "System Infrastructure": [
          EngineSystem.Application,
          EngineSystem.Supervisor,
          EngineSystem.System.Registry,
          EngineSystem.System.Spawner,
          EngineSystem.System.Services,
          EngineSystem.System.Utilities,
          EngineSystem.System.Message
        ],

        # Example Implementations - learning resources
        "Example of Engines using the DSL": [
          Examples.PingEngine,
          Examples.PongEngine,
          Examples.EchoEngine,
          Examples.EnhancedEchoEngine,
          Examples.CounterEngine,
          Examples.CalculatorEngine,
          Examples.KVStoreEngine,
          Examples.InteractiveDemo,
          Examples.TestDemo,
          Examples.ComprehensiveTest
        ]
      ],

      # Enhanced formatting and features
      formatters: ["html"],

      # Skip undefined functions for the livebook file
      skip_undefined_reference_warnings_on: ["README.livemd"],

      # Search configuration for better discoverability
      search_index: true,

      # Include example modules from examples directory
      source_url_pattern: "https://github.com/anoma/engine/blob/main/%{path}#L%{line}",

      # Improved module nesting for cleaner organization
      # nest_modules_by_prefix: [
      #   EngineSystem.Engine.DSL,
      #   EngineSystem.Engine.Effects,
      #   EngineSystem.Engine,
      #   EngineSystem.System,
      #   EngineSystem.Mailbox,
      #   EngineSystem.Examples
      # ],

      # Additional configuration for better presentation
      language: "en",
      output: "doc",
      proglang: :elixir,

      # Custom ordering for better logical flow
      groups_for_docs: [
        "Primary Functions": &(&1[:section] == :primary),
        "DSL Macros": &(&1[:section] == :dsl),
        "Utility Functions": &(&1[:section] == :utility),
        "Internal Functions": &(&1[:section] == :internal)
      ]
    ]
  end
end
