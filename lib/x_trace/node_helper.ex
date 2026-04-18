defmodule XTrace.NodeHelper do
  @moduledoc false
  require Logger
  alias XTrace.TraceHelper

  def setup_node(node_name, node_type, cookie) do
    with {:ok, _} <- Node.start(node_name, node_type) do
      cond do
        is_atom(cookie) -> cookie
        is_binary(cookie) and cookie != "" -> String.to_atom(cookie)
        true -> get_host_cookie()
      end
      |> Node.set_cookie()

      :ok
    end
  end

  def shutdown_node do
    try do
      Node.stop()
    catch
      _, reason -> {:error, reason}
    end
  end

  def connect_node(node, cookie) do
    if Node.alive?() do
      node = if is_atom(node), do: node, else: :"#{node}"

      cond do
        is_atom(cookie) -> cookie
        is_binary(cookie) and cookie != "" -> String.to_atom(cookie)
        true -> Node.get_cookie()
      end
      |> then(&Node.set_cookie(node, &1))

      if Node.connect(node) do
        {:ok, node, cookie}
      else
        {:error, "failed"}
      end
    else
      {:error, "distribution_not_started"}
    end
  end

  def node_info do
    with {:ok, {node, _cookie}} <- XTrace.get_tracing_node(),
         true <- node in Node.list() do
      node_info(node)
    else
      _ ->
        node_info(Node.self())
    end
  end

  def node_info(connected_node) do
    local_node = Node.self()
    domain_list = [:net_adm.localhost() | :net_adm.host_file()] |> Enum.map(&to_string/1)
    is_self = connected_node == local_node
    node_list = Node.list()
    code_mode = get_code_mode(is_self, connected_node)

    %{
      connected_node: connected_node,
      local_node: local_node,
      is_self: is_self,
      node_list: [local_node | node_list],
      domain_list: domain_list,
      code_mode: code_mode
    }
  end

  def elixir_node?(node) do
    case TraceHelper.call(node, :code, :is_loaded, [:elixir]) do
      {:file, _} -> true
      _ -> false
    end
  end

  def change_to_self, do: change_node(Node.self())

  def change_node(node) do
    cookie = :erlang.get_cookie(node)
    XTrace.set_tracing_node({node, cookie})
    node_info(node)
  end

  def get_host_cookie do
    Path.expand("~/.erlang.cookie")
    |> File.read()
    |> case do
      {:ok, cookie} -> String.trim(cookie) |> String.to_atom()
      _ -> Node.get_cookie()
    end
  end

  def init_erlang_distributed do
    # Make Sure Host File
    with {:error, :enoent} <- :net_adm.host_file() do
      host_file = Path.expand("~/.hosts.erlang")

      if not File.exists?(host_file) do
        File.write!(host_file, "'127.0.0.1'.\n")
        Logger.info("Successfully created the host file: #{host_file}")
      end
    end

    # ping world nodes
    :net_adm.world()
  end

  def autocomplete_nodename(name) when is_binary(name) do
    if String.contains?(name, "@") do
      String.to_atom(name)
    else
      :"#{name}@#{:net_adm.localhost()}"
    end
  end

  def get_code_mode(true, _node), do: :code.get_mode()

  def get_code_mode(false, node) do
    case TraceHelper.call(node, :code, :get_mode, []) do
      mode when is_atom(mode) -> mode
      _ -> :unknown
    end
  end
end
