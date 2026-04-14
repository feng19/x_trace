defmodule XTrace.TraceHelper do
  @moduledoc false
  alias XTrace.IoServer

  @deps_modules [
    XTrace.Executor,
    XTrace.Formatter,
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
      [{:io_server, io_server} | options],
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
    modules = @deps_modules

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

  defp format_calls_return(0), do: "=> zero trace, calls failed!"
  defp format_calls_return(i) when is_integer(i), do: "=> #{i}, tracing..."
  defp format_calls_return(msg) when is_binary(msg), do: msg

  defp format_calls_return({error, reason, stacktrace}),
    do: Exception.format(error, reason, stacktrace)

  defp format_calls_return(error), do: inspect(error)
end
