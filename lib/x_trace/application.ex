defmodule XTrace.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    load_config_from_cli()

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
        output_server_info()
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

  defp load_config_from_cli do
    {args, _, _} =
      Burrito.Util.Args.get_arguments()
      |> OptionParser.parse(
        aliases: [p: :port],
        strict: [open: :boolean, ip: :string, port: :integer]
      )

    endpoint = Application.get_env(:x_trace, XTraceWeb.Endpoint)

    endpoint =
      with ip when is_binary(ip) <- Keyword.get(args, :ip),
           {:ok, ip} <- ip |> String.to_charlist() |> :inet.parse_address() do
        Keyword.update!(endpoint, :http, &Keyword.put(&1, :ip, ip))
      else
        _ -> endpoint
      end

    endpoint =
      if port = Keyword.get(args, :port) do
        endpoint
        |> Keyword.update!(:http, &Keyword.put(&1, :port, port))
        |> Keyword.update!(:url, &Keyword.put(&1, :port, port))
      else
        endpoint
      end

    Application.put_env(:x_trace, XTraceWeb.Endpoint, endpoint)

    if browser_open = Keyword.get(args, :open, false) do
      Application.put_env(:phoenix, :browser_open, browser_open)
    end
  end

  defp output_server_info do
    if Burrito.Util.running_standalone?() do
      {args, _, _} =
        Burrito.Util.Args.get_arguments()
        |> OptionParser.parse(strict: [output_server_info: :boolean, app_data_dir: :string])

      filename =
        if data_dir = Keyword.get(args, :app_data_dir) do
          File.mkdir_p!(data_dir)
          Path.join(data_dir, ".server_info")
        else
          ".server_info"
        end

      if Keyword.get(args, :output_server_info, false) do
        {:ok, {ip, port}} = XTraceWeb.Endpoint.server_info(:http)
        File.write!(filename, "#{:inet.ntoa(ip)}:#{port}")
      end
    end
  end
end
