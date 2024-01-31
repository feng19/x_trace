defmodule XTraceWeb.TraceLive do
  use XTraceWeb, :live_view
  alias XTrace.IoServer
  require Logger

  @default_params %{
    "module" => "",
    "fun" => "_",
    "args" => "return_trace",
    "pid" => "all",
    "scope" => "global",
    "max" => 10,
    "milliseconds" => 1000,
    "node_name" => "x_trace",
    "node_domain" => "",
    "cookie" => "",
    "is_long_name" => "false"
  }
  @default_fun_list ["_"]
  @default_args_list ["return_trace", "_"]
  @banned_mods ["_", "recon_trace", "io", "lists"]
  @hello_msg """

      Tracing Elixir and Erlang Code

      The Erlang Trace BIFs allow to trace any Elixir and Erlang code at
      all. They work in two parts: pid specifications, and trace patterns.

      Pid specifications let you decide which processes to target. They
      can be specific pids, `all` pids, `existing` pids, or `new` pids
      (those not spawned at the time of the function call).

      The trace patterns represent functions. Functions can be specified
      in two parts: specifying the modules, functions, and arguments, and
      then with Erlang match specifications to add constraints to
      arguments (see `calls/3` for details).

      What defines whether you get traced or not is the intersection of
      both:

          .       _,--------,_      _,--------,_
               ,-'            `-,,-'            `-,
            ,-'              ,-'  '-,              `-,
           |   Matching    -'        '-   Matching    |
           |     Pids     |  Getting   |    Trace     |
           |              |   Traced   |  Patterns    |
           |               -,        ,-               |
            '-,              '-,  ,-'              ,-'
               '-,_          _,-''-,_          _,-'
                   '--------'        '--------'

      If either the pid specification excludes a process or a trace
      pattern excludes a given call, no trace will be received.


  !! Click [Menu] Button to start setting & trace. !!

  """

  @impl true
  def mount(_params, _session, socket) do
    Process.flag(:trap_exit, true)
    group_leader = Process.group_leader()
    code_server_mode = :code.get_mode()
    init_erlang_distributed()

    socket =
      socket
      |> assign(init_form())
      |> assign(
        menu?: false,
        clear_hello: true,
        tab: "node",
        group_leader: group_leader,
        code_server_mode: code_server_mode
      )
      |> push_event("outputs", %{data: @hello_msg})

    Phoenix.PubSub.subscribe(XTrace.PubSub, IoServer.topic())
    {:ok, socket}
  end

  @impl true
  def handle_event("validate", params, socket) do
    assigns = socket.assigns
    old_form = assigns.form
    {[target], params} = old_form.source |> Map.merge(params) |> Map.pop("_target")
    errors = old_form.errors

    {map, errors} =
      case target do
        "max" ->
          validate_max(params, errors)

        "milliseconds" ->
          validate_max(params, errors)

        "module" ->
          %{
            all_loaded: all_loaded,
            self?: self?,
            node: node,
            code_server_mode: code_server_mode
          } = assigns

          validate_mfa(
            "module",
            params["module"],
            errors,
            all_loaded,
            self?,
            node,
            code_server_mode
          )

        # "fun" ->
        #  %{all_loaded: all_loaded, self?: self?, node: node, code_server_mode: code_server_mode} = assigns
        #  validate_mfa("fun", params["fun"], errors, all_loaded, self?, node, code_server_mode)

        # "args" ->
        #  %{all_loaded: all_loaded, self?: self?, node: node, code_server_mode: code_server_mode} = assigns
        #  validate_mfa("args", params["args"], errors, all_loaded, self?, node, code_server_mode)

        "pid" ->
          pid =
            case String.to_existing_atom(params["pid"]) do
              :pid -> []
              type -> type
            end

          options = Keyword.put(assigns.options, :pid, pid)
          {%{options: options}, errors}

        "pid_str" ->
          %{self?: self?, node: node} = assigns
          validate_pid(params["pid_str"], errors, self?, node)

        "scope" ->
          scope = String.to_existing_atom(params["scope"])
          options = Keyword.put(assigns.options, :scope, scope)
          {%{options: options}, errors}

        _ ->
          {%{}, errors}
      end

    form = _to_form(params, errors)
    map = Map.put(map, :form, form)
    socket = assign(socket, map)
    %{t_specs: t_specs, options: options} = socket.assigns
    enable = trace_enable(t_specs, options, errors)
    socket = assign(socket, :disabled, not enable)
    {:noreply, socket}
  end

  def handle_event("trace", _params, socket) do
    %{self?: self?, node: node, t_specs: t_specs, max: max, options: options} = socket.assigns

    msg =
      if self? do
        local_calls(t_specs, max, options)
      else
        remote_calls(node, t_specs, max, options)
      end
      |> format_calls_return()

    socket =
      if socket.assigns.clear_hello do
        socket |> assign(:clear_hello, false) |> push_event("clear", %{})
      else
        socket
      end
      |> assign(:menu?, false)
      |> push_event("outputs", %{data: msg})

    {:noreply, socket}
  end

  def handle_event("clear", _params, socket) do
    case socket.assigns do
      %{self?: true} -> Extrace.clear()
      %{node: node} -> call(node, :recon_trace, :clear, [])
    end

    {:noreply, push_event(socket, "clear", %{})}
  end

  def handle_event("copy", _params, socket) do
    {:noreply, push_event(socket, "copy", %{})}
  end

  def handle_event("download", _params, socket) do
    {:noreply, push_event(socket, "download", %{})}
  end

  def handle_event("setup-node", _params, socket) do
    form = socket.assigns.form

    %{
      "node_name" => name,
      "node_domain" => domain,
      "is_long_name" => long_name?,
      "cookie" => cookie
    } = form.source

    {node_name, node_type} =
      case long_name? do
        "true" -> {:"#{name}@#{domain}", :longnames}
        _ -> {:"#{name}", :shortnames}
      end

    socket =
      case Node.start(node_name, node_type) do
        {:ok, _} ->
          if cookie != "" do
            cookie |> String.to_atom() |> Node.set_cookie()
          end

          # ping world nodes
          :net_adm.world()

          socket
          |> assign(domain: domain)
          |> assign(update_local_node(form))

        {:error, error} ->
          put_flash(socket, :error, "Setup node: #{node_name}, error: #{inspect(error)}")
      end

    {:noreply, socket}
  end

  def handle_event("reset-node", _params, socket) do
    Node.stop()
    Process.sleep(100)
    socket = assign(socket, update_local_node(socket.assigns.form))
    {:noreply, socket}
  end

  def handle_event("change-node", %{"node" => node}, socket) do
    socket =
      try do
        map = node |> String.to_existing_atom() |> update_node()

        assign(socket, map)
        |> put_flash(:info, "Connect to #{node} succeed!")
      catch
        _, _ -> put_flash(socket, :error, "bad node: #{node}")
      end

    {:noreply, socket}
  end

  def handle_event("connect-node", _params, socket) do
    %{"connect_node" => node, "connect_cookie" => cookie} = socket.assigns.form.source
    node = :"#{node}"

    if cookie != "" do
      String.to_atom(cookie)
    else
      Node.get_cookie()
    end
    |> then(&Node.set_cookie(node, &1))

    socket =
      if Node.connect(node) do
        {_node, nodes} = fetch_nodes()

        socket
        |> put_flash(:info, "Connect to #{node} succeed!")
        |> assign(nodes: nodes)
      else
        put_flash(socket, :error, "Connect to #{node} failed!")
      end

    {:noreply, socket}
  end

  def handle_event("add-tspec", _, socket) do
    %{form: form, t_specs: t_specs, options: options} = socket.assigns
    %{"module" => module, "fun" => fun, "args" => args} = form.source
    module = to_module(module)
    fun = String.to_existing_atom(fun)
    args = String.to_existing_atom(args)
    t_specs = Enum.uniq([{module, fun, args} | t_specs])
    enable = trace_enable(t_specs, options, form.errors)
    {:noreply, assign(socket, t_specs: t_specs, disabled: not enable)}
  end

  def handle_event("del-t_spec", %{"at" => index}, socket) do
    index = String.to_integer(index)
    %{form: form, t_specs: t_specs, options: options} = socket.assigns
    t_specs = List.delete_at(t_specs, index)
    enable = trace_enable(t_specs, options, form.errors)
    {:noreply, assign(socket, t_specs: t_specs, disabled: not enable)}
  end

  def handle_event("add-pid", _, socket) do
    %{form: form, t_specs: t_specs, options: options} = socket.assigns
    pids = [:recon_lib.term_to_pid("<#{form.source["pid_str"]}>") | options[:pid]] |> Enum.uniq()
    options = Keyword.put(options, :pid, pids)
    enable = trace_enable(t_specs, options, form.errors)
    {:noreply, assign(socket, options: options, disabled: not enable)}
  end

  def handle_event("del-pid", %{"at" => index}, socket) do
    index = String.to_integer(index)
    %{form: form, t_specs: t_specs, options: options} = socket.assigns
    pids = List.delete_at(options[:pid], index)
    options = Keyword.put(options, :pid, pids)
    enable = trace_enable(t_specs, options, form.errors)
    {:noreply, assign(socket, options: options, disabled: not enable)}
  end

  def handle_event("reset-settings", _, socket) do
    {:noreply, assign(socket, init_form())}
  end

  def handle_event("save-settings", _, socket) do
    item = socket.assigns |> Map.take([:t_specs, :max, :options])
    data = :erlang.term_to_binary(item) |> Base.encode64()

    item =
      Map.new(item, fn {k, v} -> {k, inspect_value(v)} end)
      |> Map.put(:data, data)

    {:reply, item, assign(socket, :tab, "local-settings")}
  end

  def handle_event("apply-settings", data, socket) do
    {:noreply, assign(socket, apply_settings(data))}
  end

  def handle_event("set-tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :tab, tab)}
  end

  def handle_event("menu", _, socket) do
    {:noreply, assign(socket, :menu?, not socket.assigns.menu?)}
  end

  def handle_event("term-cols", %{"cols" => cols}, socket) do
    width = max(20, cols - 10)
    Application.put_env(:extrace, :inspect_opts, pretty: true, width: width)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:io_stream, msg}, socket) do
    {:noreply, push_event(socket, "outputs", %{data: msg})}
  end

  def handle_info({:EXIT, _pid, :normal}, socket) do
    Process.group_leader(self(), socket.assigns.group_leader)
    {:noreply, socket}
  end

  defp _to_form(params, errors \\ []) do
    to_form(params, errors: errors)
  end

  defp validate_max(params, errors) do
    case check_integer(params, "max") do
      {:ok, max} when max > 1000 ->
        {%{}, Keyword.put(errors, :max, {"too big", []})}

      {:ok, max} ->
        case String.trim(params["milliseconds"]) do
          "" ->
            {%{max: max}, Keyword.drop(errors, [:max, :milliseconds])}

          _ ->
            case check_integer(params, "milliseconds") do
              {:ok, m} ->
                {%{max: {max, m}}, Keyword.drop(errors, [:max, :milliseconds])}

              {:error, error} ->
                {%{}, Keyword.put(errors, :milliseconds, {error, []})}
            end
        end

      {:error, error} ->
        {%{}, Keyword.put(errors, :max, {error, []})}
    end
  end

  defp validate_mfa("module", "", errors, all_loaded, self?, node, code_server_mode) do
    errors = Keyword.put(errors, :module, {"please enter module", []})

    all_loaded =
      case {code_server_mode, self?} do
        {:interactive, true} -> all_loaded(:local)
        {:interactive, false} -> all_loaded(node)
        _ -> all_loaded
      end

    {%{
       all_loaded: all_loaded,
       module_list: all_loaded,
       fun_list: @default_fun_list,
       add_tspec_disabled: false
     }, errors}
  end

  defp validate_mfa("module", "_", errors, all_loaded, _self?, _node, _code_server_mode) do
    errors = Keyword.put(errors, :module, {"module can't defined as '_'", []})
    {%{module_list: all_loaded, fun_list: @default_fun_list, add_tspec_disabled: false}, errors}
  end

  defp validate_mfa("module", module, errors, all_loaded, self?, node, code_server_mode) do
    module_list = Enum.filter(all_loaded, &String.starts_with?(&1, module))

    {fun_list, errors} =
      if Enum.member?(all_loaded, module) do
        {:module, to_module(module)}
      else
        try_load? = code_server_mode == :interactive

        case {self?, try_load?} do
          {true, true} -> to_module(module) |> Code.ensure_loaded()
          {false, true} -> ensure_loaded(node, module)
          _ -> {:error, :nofile}
        end
      end
      |> case do
        {:module, m} ->
          {fun_list(self?, node, m), Keyword.delete(errors, :module)}

        _ ->
          {["_"], Keyword.put(errors, :module, {"not found", []})}
      end

    enable = is_nil(errors[:module]) and is_nil(errors[:fun]) and is_nil(errors[:args])
    {%{module_list: module_list, fun_list: fun_list, add_tspec_disabled: not enable}, errors}
  end

  defp validate_pid(pid, errors, self?, node) do
    pid = :recon_lib.term_to_pid("<#{pid}>")

    if self? do
      Process.alive?(pid)
    else
      call(node, :erlang, :is_process_alive, [pid])
    end
    |> if do
      {%{add_pid_disabled: false}, Keyword.delete(errors, :pid_str)}
    else
      {%{add_pid_disabled: true}, Keyword.put(errors, :pid_str, {"pid not alive", []})}
    end
  catch
    _, _ ->
      {%{add_pid_disabled: true}, Keyword.put(errors, :pid_str, {"bad pid", []})}
  end

  defp check_integer(params, key) do
    params
    |> Map.get(key)
    |> String.trim()
    |> Integer.parse()
    |> case do
      {max, _} -> {:ok, max}
      :error -> {:error, "not integer"}
    end
  end

  defp fetch_nodes do
    node = Node.self()
    nodes = Enum.map([Node.self() | Node.list()], &to_string/1)
    {node, nodes}
  end

  defp local_calls(t_specs, max, options) when is_list(t_specs) do
    io_server = IoServer.pid()
    Process.group_leader(self(), io_server)
    ensure_loaded(t_specs)
    IoServer.puts("Extrace.calls(#{inspect(t_specs)}, #{inspect(max)}, #{inspect(options)}")

    Extrace.calls(t_specs, max, [{:io_server, io_server} | options])
    |> format_calls_return()
    |> IoServer.puts()

    ""
  rescue
    reason ->
      Exception.format(:error, reason, __STACKTRACE__)
  catch
    error, reason ->
      Exception.format(error, reason, __STACKTRACE__)
  end

  defp remote_calls(node, t_specs, max, options) when is_list(t_specs) do
    io_server = IoServer.pid()
    options = [{:io_server, IoServer.pid()} | options]

    modules =
      if elixir_node?(node) do
        [XTrace.Executor, Extrace, :recon_trace, :recon_lib]
      else
        [XTrace.Executor, :recon_trace, :recon_lib, :recon_rec, :recon_map]
      end

    for module <- modules do
      md5 = module.module_info(:md5)

      case module_md5(node, module) do
        ^md5 ->
          true

        _ ->
          {module, binary, filename} = :code.get_object_code(module)
          match?({:module, ^module}, load_binary(node, module, filename, binary))
      end
    end

    ensure_loaded(node, t_specs)

    IoServer.puts("Extrace.calls(#{inspect(t_specs)}, #{inspect(max)}, #{inspect(options)}")

    call(node, XTrace.Executor, :calls, [t_specs, max, options, io_server])
    |> format_calls_return()
    |> IoServer.puts()

    ""
  end

  defp module_md5(node, module), do: call(node, module, :module_info, [:md5])

  defp load_binary(node, module, filename, binary),
    do: call(node, :code, :load_binary, [module, filename, binary])

  defp call(node, m, f, a, timeout \\ 5000), do: :rpc.call(node, m, f, a, timeout)

  defp ensure_loaded(t_specs) when is_list(t_specs) do
    for {module, _, _} <- t_specs, module != :_ and is_atom(module) do
      Code.ensure_loaded(module)
    end
  end

  defp ensure_loaded(node, t_specs) when is_list(t_specs) do
    for {module, _, _} <- t_specs, module != :_ and is_atom(module) do
      call(node, :code, :ensure_loaded, [module])
    end
  end

  defp ensure_loaded(node, module) when is_binary(module) do
    case {elixir_node?(node), first_up?(module)} do
      {true, true} ->
        call(node, Module, :concat, [[module]])

      {true, false} ->
        call(node, :erlang, :binary_to_existing_atom, [module])

      {false, true} ->
        {:error, :badfile}

      {false, false} ->
        {:error, :badfile}
    end
    |> case do
      m when is_atom(m) -> call(node, :code, :ensure_loaded, [m])
      _ -> {:error, :badfile}
    end
  end

  defp _all_loaded(list) do
    for {module, _file} <- list do
      case to_string(module) do
        "Elixir." <> m -> m
        m -> m
      end
    end
    |> Kernel.--(@banned_mods)
  end

  defp all_loaded(:local), do: :code.all_loaded() |> _all_loaded()
  defp all_loaded(node), do: call(node, :code, :all_loaded, []) |> _all_loaded()

  defp _fun_list(functions) do
    functions
    |> Enum.reduce([], fn {f, _args}, acc ->
      fun = to_string(f)

      if String.starts_with?(fun, ["_", "-", "MACRO"]) do
        acc
      else
        [fun | acc]
      end
    end)
    |> Enum.reverse()
    |> Enum.uniq()
  end

  defp fun_list(true, _node, module) do
    module.module_info(:functions) |> _fun_list()
  end

  defp fun_list(false, node, module) do
    call(node, module, :module_info, [:functions]) |> _fun_list()
  end

  defp first_up?(module) do
    first = String.at(module, 0)
    match?(^first, String.upcase(first))
  end

  defp to_module(module) do
    if first_up?(module) do
      Module.concat([module])
    else
      String.to_existing_atom(module)
    end
  end

  defp elixir_node?(node) do
    case call(node, :code, :is_loaded, [:elixir]) do
      {:file, _} -> true
      _ -> false
    end
  end

  defp update_local_node(%{source: params, errors: errors}) do
    {node, nodes} = fetch_nodes()
    update_node(node) |> Map.merge(%{nodes: nodes, form: _to_form(params, errors)})
  end

  defp update_node(node) do
    local = Node.self()

    {self?, all_loaded, code_server_mode} =
      if node == local do
        {true, all_loaded(:local), :code.get_mode()}
      else
        {false, all_loaded(node), call(node, :code, :get_mode, [])}
      end

    %{node: node, self?: self?, all_loaded: all_loaded, code_server_mode: code_server_mode}
  end

  defp pids_empty?(options) do
    pids = options[:pid]
    is_list(pids) and Enum.empty?(pids)
  end

  defp trace_enable(t_specs, options, errors) do
    Keyword.drop(errors, [:module, :fun, :args, :pid_str]) |> Enum.empty?() and
      not Enum.empty?(t_specs) and not pids_empty?(options)
  end

  defp init_form do
    {node, nodes} = fetch_nodes()
    domains = [:net_adm.localhost() | :net_adm.host_file()] |> Enum.map(&to_string/1)
    form = %{@default_params | "node_domain" => hd(domains)} |> _to_form()
    module_list = all_loaded(:local)

    %{
      form: form,
      self?: true,
      node: node,
      nodes: nodes,
      domain: hd(domains),
      domains: domains,
      all_loaded: module_list,
      t_specs: [],
      max: {10, 1000},
      options: [pid: :all, scope: :global],
      module_list: module_list,
      fun_list: @default_fun_list,
      args_list: @default_args_list,
      disabled: true,
      add_tspec_disabled: true,
      add_pid_disabled: true
    }
  end

  defp apply_settings(data) do
    %{t_specs: t_specs, max: max, options: options} =
      data |> Base.decode64!() |> :erlang.binary_to_term()

    {node, nodes} = fetch_nodes()
    domain = :net_adm.localhost() |> to_string()

    form =
      %{@default_params | "node_domain" => domain}
      |> then(fn params ->
        case max do
          max when is_integer(max) ->
            Map.merge(params, %{"max" => to_string(max), "milliseconds" => ""})

          {max, milliseconds} ->
            Map.merge(params, %{"max" => to_string(max), "milliseconds" => milliseconds})
        end
      end)
      |> then(fn params ->
        case options[:pid] do
          pids when is_list(pids) ->
            Map.put(params, "pid", "pid")

          type ->
            Map.put(params, "pid", to_string(type))
        end
      end)
      |> Map.put("scope", options[:scope])
      |> _to_form()

    enable = trace_enable(t_specs, options, [])
    module_list = all_loaded(:local)

    %{
      form: form,
      self?: true,
      node: node,
      nodes: nodes,
      all_loaded: module_list,
      t_specs: t_specs,
      max: max,
      options: options,
      module_list: module_list,
      fun_list: @default_fun_list,
      args_list: @default_args_list,
      disabled: not enable,
      add_tspec_disabled: true,
      add_pid_disabled: true
    }
  end

  defp inspect_value(v) do
    inspect(v, pretty: true, limit: :infinity, width: 40)
  end

  defp format_calls_return(0), do: "=> zero trace, calls failed!"
  defp format_calls_return(i) when is_integer(i), do: "=> #{i}, tracing..."
  defp format_calls_return(msg) when is_binary(msg), do: msg

  defp format_calls_return({error, reason, stacktrace}),
    do: Exception.format(error, reason, stacktrace)

  defp format_calls_return(error), do: inspect(error)

  defp init_erlang_distributed do
    # Make Sure Host File
    with {:error, :enoent} <- :net_adm.host_file() do
      File.write!("./.hosts.erlang", "'127.0.0.1'.\n")
    end

    # ping world nodes
    :net_adm.world()
  end
end
