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
      extra_applications: [:logger, :logger_file_backend],
      mod: {TickerBase.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ace,      "~> 0.16.6"},
      {:json,     "~> 1.2"},
      {:logger_file_backend, "0.0.10"},
      {:ex_meck,  "~> 0.2.0", only: [:test]},
      {:dialyxir, "~> 0.5", only: [:dev], runtime: false},
      {:credo,    "~> 0.10.0", only: [:dev, :test], runtime: false}
    ]
  end

  defp aliases do
    [
      test: "test --no-start"
    ]
  end
end
