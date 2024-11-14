defmodule ApacheFlinkStateFun.Umbrella.MixProject do
  use Mix.Project

   def project do
    [
      app: :apache_flink_state_fun,
      version: "0.1.0",
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
  [
    {:plug_cowboy, "~> 2.5"},
    {:protobuf, "~> 0.13.0"}
  ]
end

end