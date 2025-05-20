defmodule EngineSystem.MixProject do
  use Mix.Project

  def project do
    [
      app: :engine_system,
      version: "0.1.0",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "A formal model-adherent implementation of distributed engines",
      package: package()
    ]
  end

  # Add this function to define compilable paths
  # defp elixirc_paths(:test), do: ["lib", "test/support", "examples"]
  defp elixirc_paths(_), do: ["lib", "examples"]

  # Run "mix help compile.app" to learn about applications
  def application do
    [
      extra_applications: [:logger],
      mod: {EngineSystem.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies
  defp deps do
    [
      {:typed_struct, "~> 0.3.0"},
      {:uuid, "~> 1.1"},
      {:ex_doc, "~> 0.29", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}

    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/anoma/jonaprieto"}
    ]
  end
end
