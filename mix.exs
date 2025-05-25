defmodule EngineSystem.MixProject do
  use Mix.Project

  def project do
    [
      app: :engine_system,
      version: "0.1.0",
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "A formal model-adherent implementation of the Engine System",
      package: package(),
      dialyzer: [
        plt_add_apps: [:mix],
        flags: [:error_handling, :underspecs],
        ignore_warnings: ".dialyzer_ignore.exs"
      ]
    ]
  end

  defp elixirc_paths(_), do: ["lib", "examples", "test"]

  def application do
    [
      extra_applications: [:logger],
      mod: {EngineSystem.Application, []}
    ]
  end

  defp deps do
    [
      {:typed_struct, "~> 0.3.0"},
      {:uuid, "~> 1.1.8"},
      {:gen_stage, "~> 1.2.1"},
      {:ex_doc, "~> 0.38.0", only: :dev, runtime: false},
      {:credo, "~> 1.7.12", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4.5", only: [:dev, :test], runtime: false}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/anoma/engine"}
    ]
  end
end
