defmodule XTrace do
  @moduledoc false

  def load_config_from_cli do
    {args, _, _} =
      Burrito.Util.Args.get_arguments()
      |> OptionParser.parse(
        aliases: [p: :port],
        strict: [open: :boolean, ip: :string, port: :integer, cookie: :string]
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

    if browser_open = Keyword.get(args, :open, false),
      do: Application.put_env(:phoenix, :browser_open, browser_open)

    if cookie = Keyword.get(args, :cookie),
      do: XTrace.NodeHelper.setup_node(:x_trace, :shortnames, cookie)
  end

  def output_server_info do
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
