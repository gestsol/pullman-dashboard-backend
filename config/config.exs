# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

config :pullman_dashboard,
  ecto_repos: [PullmanDashboard.Repo]

# Configures the endpoint
config :pullman_dashboard, PullmanDashboardWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "5m+CIlPaM5mH3/8UvlR7qZFV9k0CAfRh7Fup5zR2FwO4a6ZKYZTxhmS9xR4n7yCD",
  render_errors: [view: PullmanDashboardWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: PullmanDashboard.PubSub,
  live_view: [signing_salt: "UDeXQqZF"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
