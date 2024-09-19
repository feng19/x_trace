defmodule XTraceWeb.TraceLive do
  @moduledoc false
  use XTraceWeb, :live_view
  require Logger
  import XTrace.FormatHelper
  alias XTrace.{IoServer, NodeHelper, NodeListener, TraceHelper, Validator}

  @default_fun_list []
  @default_args_list ["return_trace"]
  @default_t_spec %{app: "all", module: "", fun: :_, args: :return_trace, enable: false}

  @impl true
  def mount(_params, _session, socket) do
    node_info = NodeHelper.node_info()
    socket = default_assigns(socket, node_info, &LiveJson.initialize/3)
    XTraceWeb.Endpoint.subscribe(IoServer.topic())
    XTraceWeb.Endpoint.subscribe(NodeListener.topic())
    {:ok, socket}
  end

  @impl true
  def handle_event("init", _, socket) do
    data = %{}
    {:reply, data, socket}
  end

  def handle_event("switch-node", node, socket) do
    {reply, socket} =
      try do
        node_info = node |> String.to_existing_atom() |> NodeHelper.change_node()
        socket = default_assigns(socket, node_info, &LiveJson.push_patch/3)
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
        {:ok, node_info} ->
          socket
          |> LiveJson.push_patch("node_info", node_info)
          |> put_notice(:success, "Setup #{node_name} succeed!")

        {:error, error} ->
          put_notice(socket, :warning, "Setup #{node_name} error: #{inspect(error)}!")
      end

    {:noreply, socket}
  end

  def handle_event("shutdown-node", _params, socket) do
    socket =
      case NodeHelper.shutdown_node() do
        {:ok, node_info} ->
          socket
          |> LiveJson.push_patch("node_info", node_info)
          |> put_notice(:info, "Shutdown node succeed!")

        {:error, error} ->
          put_notice(socket, :warning, "Shutdown node error: #{inspect(error)}!")
      end

    {:noreply, socket}
  end

  def handle_event("connect-node", %{"connect_node" => node, "connect_cookie" => cookie}, socket) do
    socket =
      case NodeHelper.connect_node(node, cookie) do
        {:ok, node_info} ->
          socket
          |> put_notice(:success, "Connect to #{node} succeed!")
          |> LiveJson.push_patch("node_info", node_info)

        {:error, reason} ->
          put_notice(socket, :error, "Connect to #{node} #{reason}!")
      end

    {:noreply, socket}
  end

  def handle_event("start-trace", _params, socket) do
    {:noreply, start_trace(socket)}
  end

  def handle_event("stop-trace", _params, socket) do
    %{ljop_status: op_status, ljnode_info: node_info} = socket.assigns

    if node_info.is_self do
      Extrace.clear()
    else
      TraceHelper.call(node_info.connected_node, :recon_trace, :clear, [])
    end

    socket =
      LiveJson.push_patch(socket, "op_status", %{
        op_status
        | start_trace: true,
          save_settings: true,
          reset_settings: true,
          stop_trace: "hidden"
      })
      |> push_event("add-log", io_msg("Recon tracer stopped."))

    {:noreply, socket}
  end

  def handle_event("app-changed", "all", socket) do
    %{ljnode_info: node_info, ljt_spec: t_spec, ljspec_datalist: spec_datalist} = socket.assigns
    module_list = TraceHelper.module_list(node_info)
    defaults = Map.take(@default_t_spec, [:module, :fun, :enable])
    t_spec = Map.merge(t_spec, defaults) |> Map.put(:app, "all")

    socket =
      socket
      |> LiveJson.push_patch("t_spec", t_spec)
      |> LiveJson.push_patch("spec_datalist", %{spec_datalist | module_list: module_list})

    {:noreply, socket}
  end

  def handle_event("app-changed", app, socket) do
    %{ljnode_info: node_info, ljt_spec: t_spec, ljspec_datalist: spec_datalist} = socket.assigns
    app = String.to_existing_atom(app)
    module_list = TraceHelper.app_module_list(app, node_info)
    defaults = Map.take(@default_t_spec, [:module, :fun, :enable])
    t_spec = Map.merge(t_spec, defaults) |> Map.put(:app, app)

    socket =
      socket
      |> LiveJson.push_patch("t_spec", t_spec)
      |> LiveJson.push_patch("spec_datalist", %{spec_datalist | module_list: module_list})

    {:noreply, socket}
  end

  def handle_event("module-changed", "_", socket) do
    %{ljt_spec: t_spec, ljspec_datalist: spec_datalist} = socket.assigns

    t_spec = Validator.validate_t_spec(%{t_spec | module: :_, fun: :_, args: :return_trace})

    socket =
      socket
      |> LiveJson.push_patch("t_spec", t_spec)
      |> LiveJson.push_patch("spec_datalist", %{
        spec_datalist
        | fun_list: @default_fun_list,
          args_list: @default_args_list
      })

    {:noreply, socket}
  end

  def handle_event("module-changed", module, socket) do
    node_info = socket.assigns.ljnode_info

    socket =
      case Validator.validate_module(module, node_info) do
        {:ok, module} when is_atom(module) ->
          %{ljt_spec: t_spec, ljspec_datalist: spec_datalist} = socket.assigns

          fun_list = TraceHelper.fun_list(node_info.is_self, node_info.connected_node, module)

          t_spec =
            Validator.validate_t_spec(%{t_spec | module: module, fun: :_, args: :return_trace})

          spec_datalist =
            if Enum.member?(spec_datalist, module) do
              %{spec_datalist | fun_list: fun_list, args_list: @default_args_list}
            else
              %{
                spec_datalist
                | module_list: [format_module(module) | spec_datalist.module_list],
                  fun_list: fun_list,
                  args_list: @default_args_list
              }
            end

          socket
          |> LiveJson.push_patch("t_spec", t_spec)
          |> LiveJson.push_patch("spec_datalist", spec_datalist)

        _ ->
          put_notice(socket, :warning, "try to load module: #{module} failed!")
      end

    {:noreply, socket}
  end

  def handle_event("fun-changed", fun, socket) do
    fun = String.to_existing_atom(fun)
    %{ljnode_info: node_info, ljt_spec: t_spec, ljspec_datalist: spec_datalist} = socket.assigns

    args_list =
      TraceHelper.args_list(node_info.is_self, node_info.connected_node, t_spec.module, fun)

    t_spec = Validator.validate_t_spec(%{t_spec | fun: fun})

    socket =
      socket
      |> LiveJson.push_patch("t_spec", t_spec)
      |> LiveJson.push_patch("spec_datalist", %{
        spec_datalist
        | args_list: @default_args_list ++ args_list
      })

    {:noreply, socket}
  end

  def handle_event("args-changed", args, socket) do
    %{ljt_spec: t_spec} = socket.assigns

    args =
      case args do
        "_" -> :_
        "return_trace" -> :return_trace
        int_str -> String.to_integer(int_str)
      end

    t_spec = Validator.validate_t_spec(%{t_spec | args: args})
    socket = LiveJson.push_patch(socket, "t_spec", t_spec)
    {:noreply, socket}
  end

  def handle_event("add-tspec", _params, socket) do
    %{t_specs: t_specs, ljt_spec: t_spec, ljtrace_settings: trace_settings} = socket.assigns

    t_specs =
      case t_spec.module do
        :_ -> [{t_spec.module, t_spec.fun, t_spec.args}]
        _ -> Enum.uniq([{t_spec.module, t_spec.fun, t_spec.args} | t_specs])
      end

    socket =
      socket
      |> assign(t_specs: t_specs)
      |> update_cli(%{trace_settings | t_specs: format_t_specs(t_specs)})
      |> trace_enable()

    {:noreply, socket}
  end

  def handle_event("del-tspec", %{"index" => index}, socket) do
    index = String.to_integer(index)
    %{t_specs: t_specs, ljtrace_settings: trace_settings} = socket.assigns
    t_specs = List.delete_at(t_specs, index)

    socket =
      socket
      |> assign(t_specs: t_specs)
      |> update_cli(%{trace_settings | t_specs: format_t_specs(t_specs)})
      |> trace_enable()

    {:noreply, socket}
  end

  def handle_event("set-rate-limiting", %{"max" => max, "milliseconds" => milliseconds}, socket) do
    socket =
      case Validator.validate_rate_limiting(max, milliseconds) do
        {:ok, rate_limiting} ->
          %{ljtrace_settings: trace_settings} = socket.assigns

          socket
          |> LiveJson.push_patch("rate_limiting", rate_limiting)
          |> update_cli(%{trace_settings | max: format_rate_limiting(rate_limiting)})

        {:error, error} ->
          put_notice(socket, :warning, error)
      end

    {:noreply, socket}
  end

  def handle_event("set-scope", scope, socket) do
    scope = String.to_existing_atom(scope)

    %{ljoptions_settings: options_settings, ljtrace_settings: trace_settings, pids: pids} =
      socket.assigns

    options_settings = %{options_settings | scope: scope}

    socket =
      socket
      |> LiveJson.push_patch("options_settings", options_settings)
      |> update_cli(%{trace_settings | options: format_options(options_settings, pids)})

    {:noreply, socket}
  end

  def handle_event("set-pid", pid, socket) do
    pid = String.to_existing_atom(pid)

    %{ljoptions_settings: options_settings, ljtrace_settings: trace_settings, pids: pids} =
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
      |> LiveJson.push_patch("options_settings", options_settings)
      |> update_cli(%{trace_settings | options: format_options(options_settings, pids)})
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

    %{ljoptions_settings: options_settings} = socket.assigns

    socket =
      LiveJson.push_patch(socket, "options_settings", %{options_settings | add_pid_enable: enable})

    {:noreply, socket}
  end

  def handle_event("add-pid", %{"pid" => pid}, socket) do
    %{
      ljnode_info: node_info,
      ljoptions_settings: options_settings,
      ljtrace_settings: trace_settings,
      pids: pids
    } = socket.assigns

    socket =
      case Validator.validate_pid(pid, node_info) do
        {:ok, pid} ->
          pids = Enum.uniq([pid | pids])
          options_settings = %{options_settings | pids: format_pids(pids)}

          socket
          |> assign(pids: pids)
          |> LiveJson.push_patch("options_settings", options_settings)
          |> update_cli(%{trace_settings | options: format_options(options_settings, pids)})
          |> trace_enable()

        {:error, error} ->
          put_notice(socket, :warning, error)
      end

    {:noreply, socket}
  end

  def handle_event("del-pid", %{"index" => index}, socket) do
    index = String.to_integer(index)

    %{ljoptions_settings: options_settings, ljtrace_settings: trace_settings, pids: pids} =
      socket.assigns

    pids = List.delete_at(pids, index)
    options_settings = %{options_settings | pids: format_pids(pids)}

    socket =
      socket
      |> assign(pids: pids)
      |> LiveJson.push_patch("options_settings", options_settings)
      |> update_cli(%{trace_settings | options: format_options(options_settings, pids)})
      |> trace_enable()

    {:noreply, socket}
  end

  def handle_event("reset-settings", _, socket) do
    %{ljnode_info: node_info} = socket.assigns

    socket =
      default_assigns(socket, node_info, &LiveJson.push_patch/3)
      |> push_event("update_store", %{setting_tab: "trace-settings"})

    {:noreply, socket}
  end

  def handle_event("save-settings", _, socket) do
    %{
      t_specs: t_specs,
      pids: pids,
      ljrate_limiting: rate_limiting,
      ljoptions_settings: options_settings
    } = socket.assigns

    settings = %{
      id: System.system_time(),
      t_specs: t_specs,
      max: rate_limiting_to_max(rate_limiting),
      options: settings_to_options(options_settings, pids)
    }

    encoded = :erlang.term_to_binary(settings) |> Base.encode64()

    settings =
      Map.new(settings, fn {k, v} -> {k, inspect_value(v)} end)
      |> Map.put(:encoded, encoded)

    {:noreply, push_event(socket, "save-settings", settings)}
  end

  def handle_event("apply-settings", %{"encoded" => encoded, "quiet" => true}, socket) do
    {:noreply, apply_settings(socket, encoded, true)}
  end

  def handle_event("apply-settings", encoded, socket) do
    {:noreply, apply_settings(socket, encoded)}
  end

  @impl true
  def handle_info({:io_stream, msg}, socket) do
    socket = push_event(socket, "add-log", io_msg(msg))
    {:noreply, socket}
  end

  def handle_info({:trace_msg, msg}, socket) do
    socket = push_event(socket, "add-log", msg)
    {:noreply, socket}
  end

  def handle_info({:DOWN, _ref, :process, _, reason}, socket) do
    %{ljop_status: op_status} = socket.assigns

    socket =
      LiveJson.push_patch(socket, "op_status", %{
        op_status
        | start_trace: true,
          save_settings: true,
          reset_settings: true,
          stop_trace: "hidden"
      })
      |> put_notice(:info, "tracer down by #{reason}")

    {:noreply, socket}
  end

  def handle_info({:EXIT, _pid, :normal}, socket) do
    Process.group_leader(self(), socket.assigns.group_leader)
    {:noreply, socket}
  end

  def handle_info({:nodeup, node, _node_type}, socket) do
    %{ljnode_info: node_info} = socket.assigns
    node_info = NodeHelper.node_info(node_info.connected_node)

    socket =
      socket
      |> LiveJson.push_patch("node_info", node_info)
      |> put_notice(:info, "Node:#{node} up!")

    {:noreply, socket}
  end

  def handle_info({:nodedown, node, _node_type}, socket) do
    %{ljnode_info: node_info} = socket.assigns
    connected_node = node_info.connected_node

    socket =
      if connected_node == node do
        node_info = NodeHelper.change_to_self()

        socket
        |> default_assigns(node_info, &LiveJson.push_patch/3)
        |> put_notice(
          :warning,
          "Node:#{node} was downed, changed to connect node: #{node_info.connected_node}"
        )
      else
        node_info = NodeHelper.node_info(connected_node)

        if Enum.count(node_info.node_list) !== 1 do
          socket
          |> default_assigns(node_info, &LiveJson.push_patch/3)
          |> put_notice(:info, "Node:#{node} was downed!")
        else
          # node was downed, so just ignore this message

          default_assigns(socket, node_info, &LiveJson.push_patch/3)
        end
      end

    {:noreply, socket}
  end

  # ==============================================================
  # internal functions
  # ==============================================================

  defp put_notice(socket, kind, msg, desc \\ nil) do
    push_event(socket, "flash", %{kind: kind, msg: msg, description: desc})
  end

  defp default_assigns(socket, node_info, assign_fun) do
    app_list = ["all" | TraceHelper.app_list(node_info)]
    module_list = TraceHelper.module_list(node_info)
    rate_limiting = %{max: 10, milliseconds: 1000}

    socket
    |> assign(t_specs: [], pids: [])
    |> assign_fun.("node_info", node_info)
    |> assign_fun.("trace_settings", %{
      t_specs: [],
      max: format_rate_limiting(rate_limiting),
      options: "[scope: :local]",
      cli: TraceHelper.cli_command([], rate_limiting_to_max(rate_limiting), scope: :local)
    })
    |> assign_fun.("rate_limiting", rate_limiting)
    |> assign_fun.("options_settings", %{
      scope: :local,
      pid: :all,
      pids: [],
      add_pid_enable: false
    })
    |> assign_fun.("op_status", %{
      start_trace: false,
      stop_trace: "hidden",
      save_settings: false,
      reset_settings: false
    })
    |> assign_fun.("t_spec", @default_t_spec)
    |> assign_fun.("spec_datalist", %{
      app_list: app_list,
      module_list: module_list,
      fun_list: @default_fun_list,
      args_list: @default_args_list
    })
  end

  defp trace_enable(socket) do
    %{
      t_specs: t_specs,
      pids: pids,
      ljop_status: op_status,
      ljoptions_settings: options_settings
    } = socket.assigns

    enable = not Enum.empty?(t_specs)

    enable =
      case options_settings.pid do
        :pid -> enable and not Enum.empty?(pids)
        _ -> enable
      end

    LiveJson.push_patch(socket, "op_status", %{
      op_status
      | start_trace: enable,
        save_settings: enable,
        reset_settings: enable
    })
  end

  defp settings_to_options(options_settings, pids) do
    options_settings.scope

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
      t_specs: t_specs,
      pids: pids,
      ljop_status: op_status,
      ljnode_info: node_info,
      ljrate_limiting: rate_limiting,
      ljoptions_settings: options_settings
    } = socket.assigns

    max = rate_limiting_to_max(rate_limiting)
    options = settings_to_options(options_settings, pids)

    if node_info.is_self do
      IoServer.puts("Start tracing on this node")
      TraceHelper.local_calls(t_specs, max, options)
    else
      IoServer.puts("Start tracing on node: #{node_info.connected_node}")
      TraceHelper.remote_calls(node_info.connected_node, t_specs, max, options)
    end

    TraceHelper.cli_command(t_specs, max, options) |> IoServer.puts()

    encoded_settings =
      :erlang.term_to_binary(%{t_specs: t_specs, max: max, options: options}) |> Base.encode64()

    LiveJson.push_patch(socket, "op_status", %{
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
    %{ljoptions_settings: options_settings} = socket.assigns

    {pid, pids} =
      case options.pid do
        pids when is_list(pids) -> {:pid, pids}
        pid -> {pid, []}
      end

    socket =
      socket
      |> assign(t_specs: t_specs, pids: pids)
      |> LiveJson.push_patch("rate_limiting", rate_limiting)
      |> LiveJson.push_patch("options_settings", %{
        options_settings
        | scope: options.scope,
          pid: pid,
          pids: format_pids(pids)
      })
      |> update_cli(%{
        t_specs: format_t_specs(t_specs),
        max: format_rate_limiting(rate_limiting),
        options: format_options(options, pids),
        cli: ""
      })
      |> trace_enable()

    if quiet? do
      socket
    else
      put_notice(socket, :success, "apply settings succeed!")
    end
  end

  def update_cli(socket, trace_settings) do
    %{t_specs: t_specs, max: max, options: options} = trace_settings
    cli = "Extrace.calls([#{Enum.join(t_specs, ",")}], #{max}, #{options})"
    LiveJson.push_patch(socket, "trace_settings", %{trace_settings | cli: cli})
  end

  def rate_limiting_to_max(%{max: max, milliseconds: milliseconds}), do: {max, milliseconds}
  def rate_limiting_to_max(%{max: max}), do: max
  def max_to_rate_limiting({max, milliseconds}), do: %{max: max, milliseconds: milliseconds}
  def max_to_rate_limiting(max) when is_integer(max), do: %{max: max}

  defp io_msg(content), do: %{time: System.system_time(), type: :io, pid: "", content: content}
end
