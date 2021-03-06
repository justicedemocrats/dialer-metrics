defmodule Livevox.Application do
  use Application

  @do_things true

  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec

    # Define workers and child supervisors to be supervised
    children =
      Enum.concat(
        [
          # Core infrastructure
          supervisor(LivevoxWeb.Endpoint, []),
          supervisor(Phoenix.PubSub.PG2, [:livevox, []]),
          worker(Livevox.Scheduler, []),
          worker(Mongo, [
            [
              name: :mongo,
              database: "livevox",
              username: Application.get_env(:livevox, :mongodb_username),
              password: Application.get_env(:livevox, :mongodb_password),
              seeds: Application.get_env(:livevox, :mongodb_seeds),
              port: Application.get_env(:livevox, :mongodb_port),
              pool: DBConnection.Poolboy
            ]
          ]),

          # Caches / data sources
          worker(Livevox.Session, []),
          worker(Livevox.ServiceInfo, []),
          worker(Livevox.AgentInfo, []),
          worker(Livevox.AirtableCache, []),
          worker(Livevox.MessageEngineConfig, []),
          worker(Livevox.CampaignControllerConfig, [])
        ],
        if @do_things do
          # Feeds
          [
            worker(Livevox.ServiceStatFeed, []),
            worker(Livevox.AgentEventFeed, []),
            worker(Livevox.CallEventFeed, []),

            # # Metrics
            # # worker(Livevox.Metrics.CallerCounts, []),
            worker(Livevox.Metrics.CallCounts, []),
            worker(Livevox.Metrics.MonitorDropCounts, []),
            worker(Livevox.Metrics.LandsDropCounts, []),
            worker(Livevox.Metrics.ServiceLevel, []),
            worker(Livevox.Metrics.WaitTime, []),
            worker(Livevox.Metrics.SessionLength, []),
            worker(Livevox.Metrics.CallLength, []),

            # # Event loggers
            worker(Livevox.EventLoggers.CallEvent, []),
            worker(Livevox.EventLoggers.AgentEvent, []),
            # # worker(Livevox.EventLoggers.CallResult, []),

            # # Aggregators
            worker(Livevox.Aggregators.ServiceConfig, []),
            worker(Livevox.Aggregators.AgentStatus, []),

            # # Interactors
            worker(Livevox.Interactors.MessageEngine, [])
          ]
        else
          []
        end
      )

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Livevox.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    LivevoxWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
