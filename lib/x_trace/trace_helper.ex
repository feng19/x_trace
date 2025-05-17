defmodule XTrace.TraceHelper do
  @moduledoc false
  alias XTrace.{IoServer, NodeHelper, FormatHelper}

  @banned_mods ["recon_trace", "io", "lists"]
  @deps_modules [
    XTrace.Executor,
    XTrace.Formatter,
    Extrace.MapLimiter,
    :recon_trace,
    :recon_lib,
    :recon_rec,
    :recon_map
  ]

  def cli_command(t_specs, max, options) do
    "Extrace.calls(#{inspect(t_specs, limit: :infinity)}, #{inspect(max)}, #{inspect(options, limit: :infinity)})"
  end

  def local_calls(t_specs, max, options) when is_list(t_specs) do
    io_server = IoServer.pid()
    Process.group_leader(self(), io_server)
    ensure_loaded(t_specs)

    Extrace.calls(t_specs, max, [
      {:io_server, io_server},
      {:formatter, &XTrace.Formatter.format/1} | options
    ])
    |> format_calls_return()
    |> IoServer.puts()

    monitor_recon_trace_tracer(nil)
    ""
  rescue
    reason ->
      Exception.format(:error, reason, __STACKTRACE__)
  catch
    error, reason ->
      Exception.format(error, reason, __STACKTRACE__)
  end

  def remote_calls(node, t_specs, max, options) when is_list(t_specs) do
    io_server = IoServer.pid()
    ensure_remote_loaded_deps_modules(node)
    ensure_loaded(node, t_specs)

    call(node, XTrace.Executor, :calls, [
      t_specs,
      max,
      [{:io_server, IoServer.pid()} | options],
      io_server
    ])
    |> format_calls_return()
    |> IoServer.puts()

    monitor_recon_trace_tracer(node)

    ""
  end

  def monitor_recon_trace_tracer(node) do
    if node do
      # remote
      Process.monitor({:recon_trace_tracer, node})
    else
      # local
      Process.monitor(:recon_trace_tracer)
    end
  end

  defp ensure_remote_loaded_deps_modules(node) do
    modules =
      if NodeHelper.elixir_node?(node) do
        List.delete(@deps_modules, :recon_rec)
      else
        @deps_modules
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
  end

  def module_md5(node, module), do: call(node, module, :module_info, [:md5])

  def load_binary(node, module, filename, binary),
    do: call(node, :code, :load_binary, [module, filename, binary])

  def call(node, m, f, a, timeout \\ 5000), do: :rpc.call(node, m, f, a, timeout)

  def ensure_loaded(t_specs) when is_list(t_specs) do
    for {module, _, _} <- t_specs, module != :_ and is_atom(module) do
      Code.ensure_loaded(module)
    end
  end

  def ensure_loaded(node, t_specs) when is_list(t_specs) do
    for {module, _, _} <- t_specs, module != :_ and is_atom(module) do
      call(node, :code, :ensure_loaded, [module])
    end
  end

  def ensure_loaded(node, module) when is_binary(module) do
    case {NodeHelper.elixir_node?(node), first_up?(module)} do
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

  def app_list(%{is_self: self?} = node_info) do
    if self? do
      app_list(:local)
    else
      app_list(node_info.connected_node)
    end
  end

  def app_list(:local) do
    Application.loaded_applications() |> Enum.map(&elem(&1, 0))
  end

  def app_list(node) do
    call(node, :application, :loaded_applications, []) |> Enum.map(&elem(&1, 0))
  end

  def app_module_list(app, %{is_self: self?} = node_info) do
    if self? do
      :application.get_key(app, :modules) |> _app_module_list()
    else
      call(node_info.connected_node, :application, :get_key, [app, :modules])
      |> _app_module_list()
    end
  end

  def _app_module_list({:ok, list}) do
    for module <- list do
      case to_string(module) do
        "Elixir." <> m -> m
        m -> m
      end
    end
    |> Kernel.--(@banned_mods)
  end

  def _app_module_list(_), do: []

  def module_list(%{is_self: self?} = node_info) do
    if self? do
      module_list(:local)
    else
      module_list(node_info.connected_node)
    end
  end

  def module_list(:local), do: :code.all_loaded() |> _module_list()

  def module_list(node) when is_atom(node),
    do: call(node, :code, :all_loaded, []) |> _module_list()

  defp _module_list(list) do
    for {module, _file} <- list do
      FormatHelper.format_module(module)
    end
    |> Kernel.--(@banned_mods)
  end

  def struct_list(%{is_self: self?} = node_info, module_list) do
    if self? do
      struct_list(:local, module_list)
    else
      struct_list(node_info.connected_node, module_list)
    end
  end

  def struct_list(:local, module_list) do
    Enum.reduce(module_list, [], fn module_str, acc ->
      module = to_module(module_str)

      if :erlang.function_exported(module, :__struct__, 0) do
        fields = module.__struct__() |> Map.from_struct() |> Map.keys()
        [%{module: module_str, fields: fields} | acc]
      else
        acc
      end
    end)
  end

  def struct_list(node, module_list) when is_atom(node) do
    ensure_remote_loaded_deps_modules(node)
    module_list = Enum.map(module_list, &to_module/1)

    case call(node, XTrace.Executor, :fetch_struct_list, [module_list]) do
      list when is_list(list) ->
        Enum.map(list, fn {module, struct} ->
          fields = struct |> Map.from_struct() |> Map.keys()
          %{module: module, fields: fields}
        end)

      _ ->
        []
    end
  end

  def fun_list(true, _node, module) do
    module.module_info(:functions) |> _fun_list()
  end

  def fun_list(false, node, module) do
    call(node, module, :module_info, [:functions]) |> _fun_list()
  end

  defp _fun_list(functions) do
    functions
    |> Enum.reduce([], fn
      {:module_info, _args}, acc ->
        acc

      {f, _args}, acc ->
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

  def args_list(true, _node, module, fun) do
    module.module_info(:functions)
    |> Enum.filter(&match?({^fun, _}, &1))
    |> Enum.map(&to_string(elem(&1, 1)))
  end

  def args_list(false, node, module, fun) do
    call(node, module, :module_info, [:functions])
    |> Enum.filter(&match?({^fun, _}, &1))
    |> Enum.map(&to_string(elem(&1, 1)))
  end

  def to_module(module) do
    if first_up?(module) do
      Module.concat([module])
    else
      String.to_existing_atom(module)
    end
  catch
    _, _ -> {:error, :not_existing}
  end

  defp first_up?(module) do
    first = String.at(module, 0)
    match?(^first, String.upcase(first))
  end

  defp format_calls_return(0), do: "=> zero trace, calls failed!"
  defp format_calls_return(i) when is_integer(i), do: "=> #{i}, tracing..."
  defp format_calls_return(msg) when is_binary(msg), do: msg

  defp format_calls_return({error, reason, stacktrace}),
    do: Exception.format(error, reason, stacktrace)

  defp format_calls_return(error), do: inspect(error)
end
