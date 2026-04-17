defmodule XTrace do
  @moduledoc false
  require Logger

  def get_tracing_node do
    Application.fetch_env(:x_trace, :tracing_node)
  end

  def set_tracing_node({node, _cookie} = value) when is_atom(node) do
    Application.put_env(:x_trace, :tracing_node, value)
  end

  def load_config_from_cli do
    {args, _, _} =
      Burrito.Util.Args.get_arguments()
      |> OptionParser.parse(
        aliases: [p: :port, n: :node],
        strict: [
          open: :boolean,
          ip: :string,
          port: :integer,
          cookie: :string,
          node: :string,
          sname: :string,
          name: :string
        ]
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

    cookie = Keyword.get(args, :cookie, "")
    connect_node = Keyword.get(args, :node)

    {name_type, node_name} =
      cond do
        name = Keyword.get(args, :name) ->
          {:longnames, String.to_atom(name)}

        sname = Keyword.get(args, :sname) ->
          sname = XTrace.NodeHelper.autocomplete_nodename(sname)
          {:shortnames, sname}

        true ->
          {nil, nil}
      end

    # Store node setup config for post-startup (don't start distribution yet)
    if node_name do
      Application.put_env(:x_trace, :pending_node_setup, {node_name, name_type, cookie})
    end

    # Store tracing node config for post-startup
    if connect_node do
      set_tracing_node({String.to_atom(connect_node), cookie})
    end
  end

  def setup_node do
    case Application.fetch_env(:x_trace, :pending_node_setup) do
      {:ok, {node_name, name_type, cookie}} ->
        Application.delete_env(:x_trace, :pending_node_setup)
        XTrace.NodeHelper.setup_node(node_name, name_type, cookie)

      :error ->
        :ok
    end
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
