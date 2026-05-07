defmodule ResoniteLinkEx.MixProject do
  use Mix.Project

  def project do
    [
      app: :resonite_link_ex,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      test_coverage: [ignore_modules: [Mix.Tasks.Check.Docs]],
      docs: [
        main: "readme",
        extras: ["README.md"]
      ],
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {ResoniteLinkEx.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:websockex, "~> 0.4"},
      {:elixir_uuid, "~> 1.2"},
      {:ex_doc, "~> 0.38", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end
end
