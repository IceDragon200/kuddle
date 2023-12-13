defmodule Kuddle.MixProject do
  use Mix.Project

  def project do
    [
      name: "Kuddle",
      app: :kuddle,
      description: description(),
      version: "1.0.0",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      source_url: "https://github.com/IceDragon200/kuddle",
      homepage_url: "https://github.com/IceDragon200/kuddle",
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp description do
    """
    Kuddle is a KDL Decoder, Encoder and utility library for Elixir.
    """
  end

  defp deps do
    [
      {:decimal, "~> 1.0 or ~> 2.0"},
      {:ex_doc, "~> 0.16", only: :dev},
    ]
  end

  defp package do
    [
      maintainers: ["Corey Powell"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/IceDragon200/kuddle"
      },
    ]
  end
end
