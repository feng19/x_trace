defmodule XTrace.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    XTrace.load_config_from_cli()

    children = [
      XTraceWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:x_trace, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: XTrace.PubSub},
      XTrace.IoServer,
      XTrace.NodeListener,
      # Start to serve requests, typically the last entry
      XTraceWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: XTrace.Supervisor]

    case Supervisor.start_link(children, opts) do
      {:ok, _} = return ->
        XTrace.output_server_info()
        return

      other ->
        other
    end
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    XTraceWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
