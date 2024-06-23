defmodule Ecto.PolyEmbeds.MixProject do
  use Mix.Project

  @version "0.0.1"
  @github "https://github.com/rwillians/ecto-poly-embeds"

  @description """
  A library that makes it easy for you to use polymorphic embeds in Ecto Schemas and Changesets.
  """

  def project do
    [
      app: :ecto_poly_embeds,
      version: @version,
      description: @description,
      source_url: @github,
      homepage_url: @github,
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      elixirc_options: [debug_info: Mix.env() == :dev],
      build_embedded: Mix.env() not in [:dev, :test],
      doc: [
          main: "README",
          logo: "assets/logo.png",
          source_ref: "v#{@version}",
          source_url: @github,
          extras: ["README.md", "LICENSE"]
      ],
      dialyzer: [
        plt_add_apps: [:mix],
        plt_add_deps: :apps_direct
      ],
      package: package(),
      aliases: aliases(),
      deps: deps()
    ]
  end

  def aliases do
    [
      #
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  def cli do
    [
      preferred_envs: ["test.perf": :test]
    ]
  end

  defp deps do
    [
      #
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp package do
    [
      files: ~w(lib mix.exs .formatter.exs README.md LICENSE),
      maintainers: ["Rafael Willians"],
      contributors: [],
      licenses: ["MIT"],
      links: %{
        GitHub: @github,
        Changelog: "#{@github}/releases"
      }
    ]
  end
end
