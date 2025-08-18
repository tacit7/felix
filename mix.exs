defmodule RouteWiseApi.MixProject do
  use Mix.Project

  def project do
    [
      app: :phoenix_backend,
      version: "0.1.0",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      dialyzer: dialyzer(),
      listeners: [Phoenix.CodeReloader],
      docs: docs()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {RouteWiseApi.Application, []},
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
      {:bandit, "~> 1.5"},
      {:bcrypt_elixir, "~> 3.0"},
      {:cors_plug, "~> 3.0"},
      {:dns_cluster, "~> 0.1.1"},
      {:ecto_sql, "~> 3.10"},
      {:elixir_sense, github: "elixir-lsp/elixir_sense"},
      {:finch, "~> 0.13"},
      {:gettext, "~> 0.26"},
      {:guardian, "~> 2.3"},
      {:httpoison, "~> 2.0"},
      {:jason, "~> 1.2"},
      {:jose, "~> 1.11"},
      {:logger_file_backend, "~> 0.0.13"},
      {:phoenix, "~> 1.8.0"},
      {:phoenix_ecto, "~> 4.5"},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      {:postgrex, ">= 0.0.0"},
      {:swoosh, "~> 1.5"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:ueberauth, "~> 0.7"},
      {:ueberauth_google, "~> 0.10"},
      {:geo_postgis, "~> 3.4"},
      {:redix, "~> 1.5"},

      # Development & Testing Tools
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:sobelow, "~> 0.13", only: [:dev, :test], runtime: false}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      setup: ["deps.get", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],

      # Code Quality & Analysis
      quality: ["format", "credo --strict", "dialyzer", "sobelow --config"],
      "quality.ci": ["format --check-formatted", "credo --strict", "dialyzer", "sobelow --exit"],
      security: ["sobelow --config"],
      analyze: ["credo --strict", "dialyzer"],
      docs: ["docs", "cmd open doc/index.html"]
    ]
  end

  # Dialyzer configuration
  defp dialyzer do
    [
      plt_add_apps: [:mix, :ex_unit],
      plt_core_path: "priv/plts",
      plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
      flags: [
        :error_handling,
        :race_conditions,
        :underspecs,
        :unknown,
        :unmatched_returns
      ],
      ignore_warnings: ".dialyzer_ignore.exs"
    ]
  end

  # Documentation configuration
  defp docs do
    [
      main: "RouteWiseApi",
      name: "RouteWise API",
      source_url: "https://github.com/your-org/route-wise-backend",
      homepage_url: "https://your-domain.com",
      extras: [
        "README.md",
        "docs/caching-strategy.md"
      ],
      groups_for_extras: [
        Guides: ~r/docs\/.*/
      ],
      groups_for_modules: [
        Core: [
          RouteWiseApi.Application,
          RouteWiseApi.Cache,
          RouteWiseApi.Guardian,
          RouteWiseApi.Repo
        ],
        Contexts: [
          RouteWiseApi.Accounts,
          RouteWiseApi.Places,
          RouteWiseApi.Trips,
          RouteWiseApi.Interests
        ],
        Caching: ~r/RouteWiseApi.Caching.*/,
        Services: [
          RouteWiseApi.GooglePlaces,
          RouteWiseApi.GoogleDirections,
          RouteWiseApi.PlacesService,
          RouteWiseApi.RouteService
        ],
        Schemas: ~r/.*\.(User|Place|Trip|POI|InterestCategory|UserInterest)$/
      ]
    ]
  end
end
