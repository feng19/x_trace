# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :x_trace,
  generators: [timestamp_type: :utc_datetime]

# Configures the endpoint
config :x_trace, XTraceWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: XTraceWeb.ErrorHTML, json: XTraceWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: XTrace.PubSub,
  live_view: [signing_salt: "mK2vMc0m"]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.3",
  x_trace: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :extrace, :inspect_opts, pretty: true, limit: :infinity

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
