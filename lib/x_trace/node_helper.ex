defmodule XTrace.NodeHelper do
  @moduledoc false
  alias XTrace.{TraceHelper, NodeListener}

  def setup_node(node_name, node_type, cookie) do
    with {:ok, _} <- Node.start(node_name, node_type) do
      if cookie != "" do
        String.to_atom(cookie)
      else
        get_host_cookie()
      end
      |> Node.set_cookie()

      try do
        NodeListener.start_monitor()
      catch
        _, _ -> {:error, "timeout"}
      else
        :ok -> {:ok, node_info()}
      end
    end
  end

  def shutdown_node do
    try do
      with :ok <- Node.stop() do
        NodeListener.stop_monitor()
      end
    catch
      _, _ -> {:error, "timeout"}
    else
      :ok ->
        Process.sleep(100)
        {:ok, node_info()}

      error ->
        error
    end
  end

  def connect_node(node, cookie) do
    node = :"#{node}"

    if cookie != "" do
      String.to_atom(cookie)
    else
      Node.get_cookie()
    end
    |> then(&Node.set_cookie(node, &1))

    if Node.connect(node) do
      {:ok, node_info()}
    else
      {:error, "failed"}
    end
  end

  def node_info, do: node_info(Node.self())

  def node_info(connected_node) do
    local_node = Node.self()
    domain_list = [:net_adm.localhost() | :net_adm.host_file()] |> Enum.map(&to_string/1)
    is_self = connected_node == local_node

    code_mode =
      if is_self do
        :code.get_mode()
      else
        TraceHelper.call(connected_node, :code, :get_mode, [])
      end

    %{
      connected_node: connected_node,
      local_node: local_node,
      is_self: is_self,
      node_list: [local_node | Node.list()],
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
end
