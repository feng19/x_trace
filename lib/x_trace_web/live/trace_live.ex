defmodule XTraceWeb.TraceLive do
  @moduledoc false
  use XTraceWeb, :live_view
  require Logger
  import XTrace.FormatHelper
  alias XTrace.{NodeHelper, NodeListener, Session, SessionSupervisor, SpecParser, Validator}

  @impl true
  def mount(_params, session, socket) do
    session_id = session["trace_session_id"]
    {:ok, _pid} = SessionSupervisor.ensure_session(session_id)

    node_info = NodeHelper.node_info()
    socket = assign(socket, session_id: session_id)
    socket = default_assigns(socket, node_info)

    if connected?(socket) do
      XTraceWeb.Endpoint.subscribe(Session.topic(session_id))
      XTraceWeb.Endpoint.subscribe(NodeListener.topic())
      Session.register_live_view(session_id)
    end

    {:ok, socket}
  end

  @impl true
  def handle_event("init", _, socket) do
    data = %{}
    {:reply, data, socket}
  end

  def handle_event("format-details", %{"type" => type, "trace_info" => trace_info}, socket) do
    type = String.to_existing_atom(type)
    details = XTrace.Formatter.format_details(type, trace_info)
    {:reply, %{details: details}, socket}
  end

  def handle_event("copy-recall-cli", %{"trace_info" => trace_info}, socket) do
    content = XTrace.Formatter.format_recall_cli(trace_info)
    {:reply, %{recall_cli: content}, socket}
  end

  def handle_event("switch-node", %{"node" => node}, socket) do
    {reply, socket} =
      try do
        node_info = node |> String.to_existing_atom() |> NodeHelper.change_node()
        socket = switch_node_assigns(socket, node_info)
        {%{code: 0, msg: "Connect to #{node} succeed!"}, socket}
      catch
        _, _ ->
          {%{code: 1, msg: "Error... :( bad node: #{node}!"}, socket}
      end

    {:reply, reply, socket}
  end

  def handle_event(
        "setup-node",
        %{"node_name" => name, "cookie" => cookie, "is_long_name" => long?} = params,
        socket
      ) do
    {node_name, node_type} =
      case long? do
        "true" ->
          domain = params["node_domain"]
          {:"#{name}@#{domain}", :longnames}

        _ ->
          {:"#{name}", :shortnames}
      end

    socket =
      case NodeHelper.setup_node(node_name, node_type, cookie) do
        :ok ->
          socket
          |> assign(:node_info, NodeHelper.node_info())
          |> put_notice(:success, "Setup #{node_name} succeed!")

        {:error, error} ->
          put_notice(socket, :warning, "Setup #{node_name} error: #{inspect(error)}!")
      end

    {:noreply, socket}
  end

  def handle_event("shutdown-node", _params, socket) do
    socket =
      case NodeHelper.shutdown_node() do
        :ok ->
          Process.sleep(100)

          socket
          |> assign(:node_info, NodeHelper.node_info(Node.self()))
          |> put_notice(:info, "Shutdown node succeed!")

        {:error, error} ->
          put_notice(socket, :warning, "Shutdown node error: #{inspect(error)}!")
      end

    {:noreply, socket}
  end

  def handle_event("connect-node", %{"connect_node" => node, "connect_cookie" => cookie}, socket) do
    node = NodeHelper.autocomplete_nodename(node)

    socket =
      case NodeHelper.connect_node(node, cookie) do
        {:ok, node, cookie} ->
          NodeListener.monitor_node(node, cookie)

          socket
          |> assign(:node_info, NodeHelper.node_info(node))
          |> put_notice(:success, "Connect to #{node} succeed!")

        {:error, reason} ->
          put_notice(socket, :error, "Connect to #{node} #{reason}!")
      end

    {:noreply, socket}
  end

  def handle_event("start-trace", _params, socket) do
    {:noreply, start_trace(socket)}
  end

  def handle_event("stop-trace", _params, socket) do
    %{session_id: session_id, op_status: op_status} = socket.assigns
    Session.stop_trace(session_id)

    socket =
      assign(socket, :op_status, %{
        op_status
        | start_trace: true,
          save_settings: true,
          reset_settings: true,
          stop_trace: "hidden"
      })
      |> push_event("add-log", io_msg("Tracer stopped."))

    {:noreply, socket}
  end

  def handle_event("import-tspecs", %{"raw" => raw}, socket) do
    with {:ok, new_specs} <- SpecParser.parse(raw),
         :ok <- SpecParser.check_banned_mods(new_specs) do
      %{t_specs: t_specs, trace_settings: trace_settings} = socket.assigns
      t_specs = Enum.uniq(new_specs ++ t_specs)

      socket =
        socket
        |> assign(t_specs: t_specs)
        |> assign(:trace_settings, %{trace_settings | t_specs: format_t_specs(t_specs)})
        |> trace_enable()

      {:reply, %{code: 0, msg: "Imported #{length(new_specs)} spec(s)"}, socket}
    else
      {:error, reason} ->
        socket = put_notice(socket, "error", "Import failed", reason)
        {:reply, %{code: 1, msg: reason}, socket}
    end
  end

  def handle_event("del-tspec", %{"index" => index}, socket) do
    %{t_specs: t_specs, trace_settings: trace_settings} = socket.assigns
    t_specs = List.delete_at(t_specs, index)

    socket =
      socket
      |> assign(t_specs: t_specs)
      |> assign(:trace_settings, %{trace_settings | t_specs: format_t_specs(t_specs)})
      |> trace_enable()

    {:noreply, socket}
  end

  def handle_event("clear-tspecs", _params, socket) do
    %{trace_settings: trace_settings} = socket.assigns

    socket =
      socket
      |> assign(t_specs: [])
      |> assign(:trace_settings, %{trace_settings | t_specs: []})
      |> trace_enable()

    {:noreply, socket}
  end

  def handle_event("set-rate-limiting", %{"max" => max, "milliseconds" => milliseconds}, socket) do
    socket =
      case Validator.validate_rate_limiting(max, milliseconds) do
        {:ok, rate_limiting} ->
          %{
            t_specs: t_specs,
            pids: pids,
            trace_settings: trace_settings,
            options_settings: options_settings
          } = socket.assigns

          socket
          |> assign(:rate_limiting, rate_limiting)
          |> assign(:trace_settings, %{trace_settings | max: format_rate_limiting(rate_limiting)})
          |> save_curr_settings(t_specs, rate_limiting, options_settings, pids)

        {:error, error} ->
          put_notice(socket, :warning, error)
      end

    {:noreply, socket}
  end

  def handle_event("set-scope", scope, socket) do
    scope = String.to_existing_atom(scope)

    %{
      t_specs: t_specs,
      pids: pids,
      rate_limiting: rate_limiting,
      options_settings: options_settings,
      trace_settings: trace_settings
    } =
      socket.assigns

    options_settings = %{options_settings | scope: scope}

    socket =
      socket
      |> assign(:options_settings, options_settings)
      |> assign(:trace_settings, %{trace_settings | options: format_options(options_settings, pids)})
      |> save_curr_settings(t_specs, rate_limiting, options_settings, pids)

    {:noreply, socket}
  end

  def handle_event("set-pid", pid, socket) do
    pid = String.to_existing_atom(pid)

    %{options_settings: options_settings, trace_settings: trace_settings, pids: pids} =
      socket.assigns

    {pids, options_settings} =
      case pid do
        :pid when options_settings.pid != :pid ->
          {[], %{options_settings | pid: pid, pids: []}}

        _ ->
          {pids, %{options_settings | pid: pid}}
      end

    socket =
      socket
      |> assign(pids: pids)
      |> assign(:options_settings, options_settings)
      |> assign(:trace_settings, %{trace_settings | options: format_options(options_settings, pids)})
      |> trace_enable()

    {:noreply, socket}
  end

  def handle_event("validate-pid", %{"pid" => pid}, socket) do
    enable =
      with [a, b, c] <- String.split(pid, "."),
           {_a, ""} <- Integer.parse(a),
           {_b, ""} <- Integer.parse(b),
           {_c, ""} <- Integer.parse(c) do
        true
      else
        _ -> false
      end

    %{options_settings: options_settings} = socket.assigns

    socket =
      assign(socket, :options_settings, %{options_settings | add_pid_enable: enable})

    {:noreply, socket}
  end

  def handle_event("add-pid", %{"pid" => pid}, socket) do
    %{
      node_info: node_info,
      options_settings: options_settings,
      trace_settings: trace_settings,
      pids: pids
    } = socket.assigns

    socket =
      case Validator.validate_pid(pid, node_info) do
        {:ok, pid} ->
          pids = Enum.uniq([pid | pids])
          options_settings = %{options_settings | pids: format_pids(pids)}

          socket
          |> assign(pids: pids)
          |> assign(:options_settings, options_settings)
          |> assign(:trace_settings, %{trace_settings | options: format_options(options_settings, pids)})
          |> trace_enable()

        {:error, error} ->
          put_notice(socket, :warning, error)
      end

    {:noreply, socket}
  end

  def handle_event("del-pid", %{"index" => index}, socket) do
    %{options_settings: options_settings, trace_settings: trace_settings, pids: pids} =
      socket.assigns

    pids = List.delete_at(pids, index)
    options_settings = %{options_settings | pids: format_pids(pids)}

    socket =
      socket
      |> assign(pids: pids)
      |> assign(:options_settings, options_settings)
      |> assign(:trace_settings, %{trace_settings | options: format_options(options_settings, pids)})
      |> trace_enable()

    {:noreply, socket}
  end

  def handle_event("reset-settings", _, socket) do
    %{node_info: node_info} = socket.assigns

    socket =
      default_assigns(socket, node_info)
      |> push_event("update_store", %{setting_tab: "trace-settings"})

    %{
      t_specs: t_specs,
      pids: pids,
      rate_limiting: rate_limiting,
      options_settings: options_settings
    } = socket.assigns

    socket = save_curr_settings(socket, t_specs, rate_limiting, options_settings, pids)

    {:noreply, socket}
  end

  def handle_event("save-settings", %{"name" => name}, socket) do
    %{
      t_specs: t_specs,
      pids: pids,
      rate_limiting: rate_limiting,
      options_settings: options_settings
    } = socket.assigns

    settings = %{
      id: System.system_time(),
      t_specs: t_specs,
      max: rate_limiting_to_max(rate_limiting),
      options: settings_to_options(options_settings, pids)
    }

    encoded = :erlang.term_to_binary(settings, [:compressed]) |> Base.encode64()

    settings =
      Map.new(settings, fn {k, v} -> {k, inspect_value(v)} end)
      |> Map.put(:encoded, encoded)
      |> Map.put(:name, name)

    {:noreply, push_event(socket, "save-settings", settings)}
  end

  def handle_event("apply-settings", %{"encoded" => encoded, "quiet" => true}, socket) do
    {:noreply, apply_settings(socket, encoded, true)}
  end

  def handle_event("apply-settings", encoded, socket) do
    {:noreply, apply_settings(socket, encoded)}
  end

  @impl true
  def handle_info({:trace_msg, msg}, socket) do
    socket = push_event(socket, "add-log", msg)
    {:noreply, socket}
  end

  def handle_info({:session_info, msg}, socket) do
    socket = push_event(socket, "add-log", io_msg(msg))
    {:noreply, socket}
  end

  def handle_info({:session_stopped, reason}, socket) do
    %{op_status: op_status} = socket.assigns

    socket =
      assign(socket, :op_status, %{
        op_status
        | start_trace: true,
          save_settings: true,
          reset_settings: true,
          stop_trace: "hidden"
      })
      |> put_notice(:info, "Tracer stopped: #{inspect(reason)}")

    {:noreply, socket}
  end

  def handle_info({:nodeup, node, _node_type}, socket) do
    %{node_info: node_info} = socket.assigns
    node_info = NodeHelper.node_info(node_info.connected_node)

    socket =
      socket
      |> assign(:node_info, node_info)
      |> put_notice(:info, "Node:#{node} up!")

    {:noreply, socket}
  end

  def handle_info({:nodedown, node, _node_type}, socket) do
    %{node_info: node_info} = socket.assigns
    connected_node = node_info.connected_node

    socket =
      if connected_node == node do
        node_info = NodeHelper.change_to_self()

        socket
        |> default_assigns(node_info)
        |> put_notice(
          :warning,
          "Node:#{node} was downed, changed to connect node: #{node_info.connected_node}"
        )
      else
        node_info = NodeHelper.node_info(connected_node)

        if Enum.count(node_info.node_list) !== 1 do
          socket
          |> switch_node_assigns(node_info)
          |> put_notice(:info, "Node:#{node} was downed!")
        else
          switch_node_assigns(socket, node_info)
        end
      end

    {:noreply, socket}
  end

  def handle_info(unknown_info, socket) do
    Logger.warning("Trace Live got unknown info: #{inspect(unknown_info)}")
    {:noreply, socket}
  end

  # ==============================================================
  # internal functions
  # ==============================================================

  defp put_notice(socket, kind, msg, desc \\ nil) do
    push_event(socket, "flash", %{kind: kind, msg: msg, description: desc})
  end

  defp default_assigns(socket, node_info) do
    rate_limiting = %{max: 10, milliseconds: 1000}
    version = to_string(Application.spec(:x_trace, :vsn) || "dev")

    socket
    |> assign(t_specs: [], pids: [])
    |> assign(:node_info, node_info)
    |> assign(:version, version)
    |> assign(:trace_settings, %{
      t_specs: [],
      max: format_rate_limiting(rate_limiting),
      options: "[scope: :local]"
    })
    |> assign(:rate_limiting, rate_limiting)
    |> assign(:options_settings, %{
      scope: :local,
      pid: :all,
      pids: [],
      add_pid_enable: false
    })
    |> assign(:op_status, %{
      start_trace: false,
      stop_trace: "hidden",
      save_settings: false,
      reset_settings: false
    })
  end

  defp switch_node_assigns(socket, node_info) do
    %{
      t_specs: t_specs,
      rate_limiting: rate_limiting,
      options_settings: options_settings
    } = socket.assigns

    # Reset PIDs (node-specific) but preserve everything else
    pids = []
    options_settings = %{options_settings | pid: :all, pids: [], add_pid_enable: false}

    socket
    |> assign(pids: pids)
    |> assign(:node_info, node_info)
    |> assign(:options_settings, options_settings)
    |> assign(:trace_settings, %{
      t_specs: format_t_specs(t_specs),
      max: format_rate_limiting(rate_limiting),
      options: format_options(options_settings, pids)
    })
    |> assign(:op_status, %{
      start_trace: false,
      stop_trace: "hidden",
      save_settings: false,
      reset_settings: false
    })
    |> trace_enable()
  end

  defp trace_enable(socket) do
    %{
      t_specs: t_specs,
      pids: pids,
      op_status: op_status,
      rate_limiting: rate_limiting,
      options_settings: options_settings
    } = socket.assigns

    enable = not Enum.empty?(t_specs)

    enable =
      case options_settings.pid do
        :pid -> enable and not Enum.empty?(pids)
        _ -> enable
      end

    socket =
      assign(socket, :op_status, %{
        op_status
        | start_trace: enable,
          save_settings: enable,
          reset_settings: enable
      })

    save_curr_settings(socket, t_specs, rate_limiting, options_settings, pids)
  end

  defp save_curr_settings(socket, t_specs, rate_limiting, options_settings, pids) do
    max = rate_limiting_to_max(rate_limiting)
    options = settings_to_options(options_settings, pids)

    encoded =
      %{t_specs: t_specs, max: max, options: options}
      |> :erlang.term_to_binary([:compressed])
      |> Base.encode64()

    push_event(socket, "save-curr-settings", %{encoded: encoded})
  end

  defp settings_to_options(options_settings, pids) do
    pid =
      case options_settings.pid do
        :pid -> pids
        pid -> pid
      end

    [scope: options_settings.scope, pid: pid]
  end

  defp format_options(options_settings, pids) do
    inspect(settings_to_options(options_settings, pids), limit: :infinity)
  end

  def start_trace(socket) do
    %{
      session_id: session_id,
      t_specs: t_specs,
      pids: pids,
      op_status: op_status,
      node_info: node_info,
      rate_limiting: rate_limiting,
      options_settings: options_settings
    } = socket.assigns

    max = rate_limiting_to_max(rate_limiting)
    options = settings_to_options(options_settings, pids)

    # Add node to options for remote tracing
    options =
      if node_info.is_self do
        Session.broadcast_session_info(session_id, "Start tracing on this node")
        options
      else
        Session.broadcast_session_info(session_id, "Start tracing on node: #{node_info.connected_node}")
        [{:node, node_info.connected_node} | options]
      end

    Session.start_trace(session_id, t_specs, max, options)

    encoded_settings =
      %{t_specs: t_specs, max: max, options: options}
      |> :erlang.term_to_binary([:compressed])
      |> Base.encode64()

    assign(socket, :op_status, %{
      op_status
      | start_trace: "hidden",
        save_settings: "hidden",
        reset_settings: "hidden",
        stop_trace: true
    })
    |> push_event("save-curr-settings", %{encoded: encoded_settings})
  end

  defp apply_settings(socket, encoded, quiet? \\ false) do
    settings = encoded |> Base.decode64!() |> :erlang.binary_to_term()
    %{t_specs: t_specs, max: max, options: options} = settings
    options = Map.new(options)
    rate_limiting = max_to_rate_limiting(max)
    %{options_settings: options_settings} = socket.assigns

    {pid, pids} =
      case options.pid do
        pids when is_list(pids) -> {:pid, pids}
        pid -> {pid, []}
      end

    socket =
      socket
      |> assign(t_specs: t_specs, pids: pids)
      |> assign(:rate_limiting, rate_limiting)
      |> assign(:options_settings, %{
        options_settings
        | scope: options.scope,
          pid: pid,
          pids: format_pids(pids)
      })
      |> assign(:trace_settings, %{
        t_specs: format_t_specs(t_specs),
        max: format_rate_limiting(rate_limiting),
        options: format_options(options, pids)
      })
      |> trace_enable()

    if quiet? do
      socket
    else
      put_notice(socket, :success, "apply settings succeed!")
    end
  end

  def rate_limiting_to_max(%{max: max, milliseconds: milliseconds}), do: {max, milliseconds}
  def rate_limiting_to_max(%{max: max}), do: max
  def max_to_rate_limiting({max, milliseconds}), do: %{max: max, milliseconds: milliseconds}
  def max_to_rate_limiting(max) when is_integer(max), do: %{max: max}

  defp io_msg(content), do: %{time: System.system_time(), type: :io, pid: "", content: content}
end
