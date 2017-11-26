use Mix.Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :livevox, LivevoxWeb.Endpoint,
  http: [port: 4001],
  server: false

# Print only warnings and errors during test
config :logger, level: :warn

# Use DummyFeed with no events in testing environment
config :livevox,
  call_feed: Livevox.DummyFeed,
  agent_feed: Livevox.DummyFeed
