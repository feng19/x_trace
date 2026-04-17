defmodule XTrace.NodeListener do
  @moduledoc """
  A cluster membership manager.

  NodeListener monitors nodes in BEAM's distribution system and automatically
  adds and removes those marked as `visible` from the cluster it's managing.

  Monitored nodes are tracked with their cookies and automatically reconnected
  on each tick if they become disconnected.
  """
  use GenServer
  require Logger
  alias XTrace.NodeHelper
  @topic inspect(__MODULE__)

  # API

  @spec start_link(any) :: GenServer.on_start()
  def start_link(_), do: GenServer.start_link(__MODULE__, [], name: __MODULE__)
  def topic, do: @topic

  def monitor_node(node, cookie),
    do: GenServer.call(__MODULE__, {:monitor_node, node, cookie}, 10_000)

  # GenServer callbacks

  @impl true
  def init(_) do
    NodeHelper.init_erlang_distributed()
    :net_kernel.monitor_nodes(true, node_type: :all)
    :timer.send_interval(3000, self(), :tick)

    nodes =
      case XTrace.get_tracing_node() do
        {:ok, {node, cookie}} -> [{node, cookie}]
        :error -> []
      end

    {:ok, %{nodes: nodes}}
  end

  @impl true
  def handle_info({:nodeup, node, _node_type} = up, state) do
    Logger.info("node: #{node} up!")
    Phoenix.PubSub.broadcast(XTrace.PubSub, @topic, up)
    {:noreply, state}
  end

  def handle_info({:nodedown, node, _node_type} = down, state) do
    Logger.warning("node: #{node} down!")
    Phoenix.PubSub.broadcast(XTrace.PubSub, @topic, down)
    {:noreply, state}
  end

  def handle_info(:tick, %{nodes: nodes} = state) do
    if Node.alive?() do
      :net_adm.world()
      connected = Node.list()

      Enum.each(nodes, fn {node, cookie} ->
        with false <- node in connected,
             {:ok, _, _} <- NodeHelper.connect_node(node, cookie) do
          Logger.info("Auto-reconnecting to node: #{node}")
        end
      end)
    end

    {:noreply, state}
  end

  def handle_info(info, state) do
    Logger.info("unknown info: #{inspect(info)}")
    {:noreply, state}
  end

  @impl true
  def handle_call({:monitor_node, node, cookie}, _from, state) do
    node = if is_atom(node), do: node, else: :"#{node}"

    nodes =
      if Enum.any?(state.nodes, fn {n, _} -> n == node end) do
        Enum.map(state.nodes, fn
          {^node, _} -> {node, cookie}
          other -> other
        end)
      else
        [{node, cookie} | state.nodes]
      end

    # Attempt immediate connection
    NodeHelper.connect_node(node, cookie)

    {:reply, :ok, %{state | nodes: nodes}}
  end
end
