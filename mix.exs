defmodule TickerBase.MixProject do
  use Mix.Project

  def project do
    [
      app: :ticker_base,
      version: "0.1.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {TickerBase.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ace, "~> 0.16.6"},
      {:poison, "~> 4.0.1"}
    ]
  end

  defp aliases do
    [
      test: "test --no-start"
    ]
  end
end
