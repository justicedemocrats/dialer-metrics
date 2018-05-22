defmodule Livevox.Mixfile do
  use Mix.Project

  def project do
    [
      app: :livevox,
      version: "0.1.24",
      elixir: "~> 1.4",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix, :gettext] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Livevox.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.3.0"},
      {:phoenix_html, "~> 2.10"},
      {:phoenix_pubsub, "~> 1.0"},
      {:gettext, "~> 0.11"},
      {:cowboy, "~> 1.0"},
      {:httpotion, "~> 3.0.3"},
      {:poison, "~> 3.1"},
      {:timex, "~> 3.1"},
      {:short_maps, "~> 0.1.2"},
      {:ecto, "~> 2.0"},
      {:postgrex, "~> 0.11"},
      {:dogstatsd, "0.0.3"},
      {:mongodb, "~> 0.4.3"},
      {:distillery, "~> 1.5", runtime: false},
      {:rollbax, "~> 0.6"},
      {:quantum, ">= 2.2.1"},
      {:flow, "~> 0.11"},
      {:poolboy, "~> 1.5.1"},
      {:airtable_config, git: "https://github.com/justicedemocrats/airtable_config.git"}
    ]
  end
end
