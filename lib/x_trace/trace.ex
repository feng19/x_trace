defmodule XTrace.Trace do
  @remote_modules [__MODULE__, XTrace.Executor, XTrace.RateLimiter]
  # tspec validation banned mods — same as Tracer had
  @banned_mods [:_, __MODULE__, :io, :lists, :trace]

  def start_trace(session_id, t_specs, options) do
    {pid_specs, trace_opts, match_opts} = parse_options(options)

    ensure_loaded(t_specs)

    # Create trace session with self() as the tracer receiver
    session_name = :"xtrace_#{session_id}"
    session = :trace.session_create(session_name, self(), [])

    # Set trace patterns
    match_count = setup_trace_patterns(session, t_specs, match_opts)

    # Enable trace flags on processes
    for pid_spec <- pid_specs do
      :trace.process(session, pid_spec, true, [:call | trace_opts])
    end

    {session, match_count}
  end

  # ===========================
  # Trace Setup Helpers
  # ===========================

  defp setup_trace_patterns(session, t_specs, match_opts) do
    for {mod, fun, args} <- t_specs, reduce: 0 do
      acc ->
        {arity, spec} = validate_tspec(mod, fun, args)
        count = :trace.function(session, {mod, fun, arity}, spec, match_opts)
        acc + count
    end
  end

  defp parse_options(options) do
    pid_specs = parse_pid_specs(Keyword.get(options, :pid, :all))
    scope = Keyword.get(options, :scope, :global)

    trace_opts =
      case Keyword.get(options, :timestamp, :formatter) do
        :formatter -> []
        :trace -> [:timestamp]
      end ++
        case Keyword.get(options, :args, :args) do
          :args -> []
          :arity -> [:arity]
        end ++
        case Keyword.get(options, :return_to) do
          true -> [:return_to]
          _ -> []
        end

    match_opts = [scope]
    {pid_specs, trace_opts, match_opts}
  end

  defp parse_pid_specs(:all), do: [:all]
  defp parse_pid_specs(:existing), do: [:existing]
  defp parse_pid_specs(:new), do: [:new]
  defp parse_pid_specs(pid) when is_pid(pid), do: [pid]
  defp parse_pid_specs([]), do: [:all]

  defp parse_pid_specs(pids) when is_list(pids) do
    Enum.flat_map(pids, &parse_pid_specs/1)
  end

  defp parse_pid_specs(name) when is_atom(name) do
    case Process.whereis(name) do
      nil -> raise ArgumentError, "no process registered as #{inspect(name)}"
      pid -> [pid]
    end
  end

  defp parse_pid_specs({a, b, c}) when is_integer(a) and is_integer(b) and is_integer(c) do
    [:erlang.list_to_pid(~c"<#{a}.#{b}.#{c}>")]
  end

  @doc false
  def validate_tspec(mod, fun, args) when is_function(args) do
    validate_tspec(mod, fun, fun_to_ms(args))
  end

  def validate_tspec(mod, fun, :return_trace) do
    validate_tspec(mod, fun, [{:_, [], [{:return_trace}, {:exception_trace}]}])
  end

  def validate_tspec(mod, fun, args) do
    case {mod in @banned_mods, args} do
      {true, :_} -> raise ArgumentError, "dangerous combo: #{inspect({mod, fun, args})}"
      {true, []} -> raise ArgumentError, "dangerous combo: #{inspect({mod, fun, args})}"
      _ -> :ok
    end

    case args do
      :_ -> {:_, true}
      _ when is_list(args) -> {:_, args}
      _ when is_integer(args) and args >= 0 and args <= 255 -> {args, true}
    end
  end

  defp fun_to_ms(shell_fun) when is_function(shell_fun) do
    case :erl_eval.fun_data(shell_fun) do
      {:fun_data, import_list, clauses} ->
        case :ms_transform.transform_from_shell(:dbg, clauses, import_list) do
          {:error, [{_, [{_, _, code} | _]} | _], _} ->
            raise "match spec error: #{:ms_transform.format_error(code)}"

          [{args, guards, [:return]}] ->
            [{args, guards, [{:return_trace}, {:exception_trace}]}]

          match_spec ->
            match_spec
        end

      false ->
        raise "only shell funs are supported"
    end
  end

  # ===========================
  # Module Loading
  # ===========================

  def ensure_loaded(t_specs) when is_list(t_specs) do
    for {module, _, _} <- t_specs, module != :_ and is_atom(module) do
      Code.ensure_loaded(module)
    end
  end

  def ensure_loaded(node, t_specs) when is_list(t_specs) do
    for {module, _, _} <- t_specs, module != :_ and is_atom(module) do
      :rpc.call(node, :code, :ensure_loaded, [module])
    end
  end

  def ensure_remote_modules(node) do
    for module <- @remote_modules do
      md5 = module.module_info(:md5)

      case :rpc.call(node, module, :module_info, [:md5]) do
        ^md5 ->
          :ok

        _ ->
          {module, binary, filename} = :code.get_object_code(module)
          :rpc.call(node, :code, :load_binary, [module, filename, binary])
      end
    end
  end
end
