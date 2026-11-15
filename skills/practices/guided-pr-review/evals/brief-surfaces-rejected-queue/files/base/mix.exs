defmodule Webhooks.MixProject do
  use Mix.Project

  def project do
    [
      app: :webhooks,
      version: "0.1.0",
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: [{:req, "~> 0.5"}]
    ]
  end

  def application, do: [extra_applications: [:logger]]

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_env), do: ["lib"]
end
