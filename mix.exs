defmodule StockApp.MixProject do
  use Mix.Project

  def project do
    [
      app: :stock_app,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: false,
      deps: deps(),
      erlc_paths: ["src"],
      erlc_options: [:debug_info]
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [
      {:mob,     "~> 0.4"},
      {:mob_dev, "~> 0.2", only: :dev, runtime: false},
      {:ecto_sqlite3, "~> 0.18"}
    ]
  end
end
