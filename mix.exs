defmodule UeberauthWeebly.MixProject do
  use Mix.Project

  @version "0.1.1"
  @url "https://github.com/nsweeting/ueberauth_weebly"

  def project do
    [
      app: :ueberauth_weebly,
      name: "Ueberauth Weebly Strategy",
      version: @version,
      package: package(),
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      source_url: @url,
      homepage_url: @url,
      description: description(),
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp package do
    [
      files: ["lib", "mix.exs", "README*", "LICENSE"],
      maintainers: ["Nicholas Sweeting"],
      licenses: ["MIT"],
      links: %{GitHub: @url}
    ]
  end

  defp description do
    """
      An Ueberauth strategy for authenticating your application with Weebly.
    """
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:oauth2, "~> 0.8.0"},
      {:ueberauth, "~> 0.4.0"},
      {:ex_doc, "~> 0.19.0", only: :dev}
    ]
  end
end
