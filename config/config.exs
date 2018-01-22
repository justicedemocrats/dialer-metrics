# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# Configures the endpoint
config :livevox, LivevoxWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "v8sVmPCZcbAofdTMu2urRfyxZATWHUmoCgsdCjCA4ZN9Vny6R+WWlmqzpyWaKZdk",
  render_errors: [view: LivevoxWeb.ErrorView, accepts: ~w(json)],
  pubsub: [name: Livevox.PubSub, adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :livevox, Livevox.Scheduler,
  jobs: [
    {"*/5 * * * *", {Livevox.AirtableCache, :update, []}},
    {"*/5 * * * *", {Livevox.ServiceInfo, :update, []}},
    {{:extended, "*/30"}, {Livevox.EventLoggers.AgentEvent, :flush, []}},
    {{:extended, "*/30"}, {Livevox.EventLoggers.CallEvent, :flush, []}},
    {{:extended, "*/30"}, {Livevox.Metrics.CallerCounts, :update, []}},
    {{:extended, "*/30"}, {Livevox.Metrics.CallCounts, :report_over_period, []}}
  ]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
