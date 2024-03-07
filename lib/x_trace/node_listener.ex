defmodule XTrace.NodeListener do
  @moduledoc """
  A cluster membership manager.

  NodeListener monitors nodes in BEAM's distribution system and automatically
  adds and removes those marked as `visible` from the cluster it's managing
  """
  use GenServer
  require Logger
  @topic inspect(__MODULE__)

  # API

  @spec start_link(any) :: GenServer.on_start()
  def start_link(_), do: GenServer.start_link(__MODULE__, [], name: __MODULE__)
  def topic, do: @topic
  def start_monitor, do: GenServer.call(__MODULE__, {:monitor, true})
  def stop_monitor, do: GenServer.call(__MODULE__, {:monitor, false})

  # GenServer callbacks

  @impl true
  def init(_) do
    init_erlang_distributed()
    :timer.send_interval(1000, self(), :tick)
    {:ok, false}
  end

  @impl true
  def handle_info({:nodeup, _node, _node_type} = up, state) do
    Phoenix.PubSub.broadcast(XTrace.PubSub, @topic, up)
    {:noreply, state}
  end

  def handle_info({:nodedown, _node, _node_type} = down, state) do
    Phoenix.PubSub.broadcast(XTrace.PubSub, @topic, down)
    {:noreply, state}
  end

  def handle_info(:tick, state) do
    if state, do: :net_adm.world()
    {:noreply, state}
  end

  def handle_info(info, state) do
    Logger.info("unknown info: #{inspect(info)}")
    {:noreply, state}
  end

  @impl true
  def handle_call({:monitor, bool}, _from, _state) do
    # ping world nodes
    :net_adm.world()
    :net_kernel.monitor_nodes(bool, node_type: :all)
    {:reply, :ok, bool}
  end

  defp init_erlang_distributed do
    # Make Sure Host File
    with {:error, :enoent} <- :net_adm.host_file() do
      File.write!("./.hosts.erlang", "'127.0.0.1'.\n")
    end

    # ping world nodes
    :net_adm.world()
  end
end
