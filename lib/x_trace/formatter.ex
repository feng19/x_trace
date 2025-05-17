defmodule XTrace.Formatter do
  @moduledoc false
  alias XTrace.IoServer

  @spec format(trace_msg :: tuple) :: iodata
  def format(trace_msg) do
    msg = extract_info(trace_msg)
    Phoenix.PubSub.broadcast(XTrace.PubSub, IoServer.topic(), {:trace_msg, msg})
    :xtrace_ignore_me
  end

  ###############
  ### Private ###
  ###############

  defp extract_info(trace_msg) do
    case :erlang.tuple_to_list(trace_msg) do
      [:trace_ts, pid, type | info] ->
        {trace_info, [timestamp]} = :lists.split(:erlang.length(info) - 1, info)
        content = format_body(type, trace_info)
        %{time: to_unixtime(timestamp), type: type, pid: format_pid(pid), content: content}

      [:trace, pid, type | trace_info] ->
        content = format_body(type, trace_info)
        %{time: System.system_time(), type: type, pid: format_pid(pid), content: content}
    end
  end

  @compile {:inline, format_body: 2}
  defp format_body(:receive, [msg]) do
    "< #{inspect(msg, inspect_opts())}"
  end

  defp format_body(:send, [msg, to]) do
    " > #{inspect(to, inspect_opts())}: #{inspect(msg, inspect_opts())}"
  end

  defp format_body(:send_to_non_existing_process, [msg, to]) do
    " > (non_existent) #{inspect(to, inspect_opts())}: #{inspect(msg, inspect_opts())}"
  end

  defp format_body(:call, [{m, f, args}]) do
    "#{format_module(m)}.#{f}#{format_args(args)}"
  end

  defp format_body(:return_to, [{m, f, arity}]) do
    "#{format_module(m)}.#{f}/#{arity}"
  end

  defp format_body(:return_from, [{m, f, arity}, return]) do
    "#{format_module(m)}.#{f}/#{arity} --> #{inspect(return, inspect_opts())}"
  end

  defp format_body(:exception_from, [{m, f, arity}, {class, val}]) do
    "#{format_module(m)}.#{f}/#{arity} #{class} #{inspect(val, inspect_opts())}"
  end

  defp format_body(:spawn, [spawned, {m, f, args}]) do
    "spawned #{inspect(spawned, inspect_opts())} as #{format_module(m)}.#{f}#{format_args(args)}"
  end

  defp format_body(:exit, [reason]) do
    "EXIT #{inspect(reason, inspect_opts())}"
  end

  defp format_body(:link, [linked]) do
    "link(#{inspect(linked, inspect_opts())})"
  end

  defp format_body(:unlink, [linked]) do
    "unlink(#{inspect(linked, inspect_opts())})"
  end

  defp format_body(:getting_linked, [linker]) do
    "getting linked by #{inspect(linker, inspect_opts())}"
  end

  defp format_body(:getting_unlinked, [unlinker]) do
    "getting unlinked by #{inspect(unlinker, inspect_opts())}"
  end

  defp format_body(:register, [name]) do
    "registered as #{inspect(name, inspect_opts())}"
  end

  defp format_body(:unregister, [name]) do
    "no longer registered as #{inspect(name, inspect_opts())}"
  end

  defp format_body(:in, [{m, f, arity}]) do
    "scheduled in for #{format_module(m)}.#{f}/#{arity}"
  end

  defp format_body(:in, [0]) do
    "scheduled in"
  end

  defp format_body(:out, [{m, f, arity}]) do
    "scheduled out from #{format_module(m)}.#{f}/#{arity}"
  end

  defp format_body(:out, [0]) do
    "scheduled out"
  end

  defp format_body(:gc_start, [info]) do
    "gc beginning -- heap #{calc_total_heap_size(info)} bytes"
  end

  defp format_body(:gc_end, [info]) do
    "gc finished -- heap #{calc_total_heap_size(info)} bytes"
  end

  defp format_body(type, trace_info) do
    "unknown trace type #{inspect(type, inspect_opts())} -- #{inspect(trace_info, inspect_opts())}"
  end

  @compile {:inline, to_unixtime: 1}
  defp to_unixtime({mega_secs, secs, micro_secs}),
    do: mega_secs * 1_000_000_000_000 + secs * 1_000_000 + micro_secs

  defp to_unixtime(_), do: System.system_time()

  @compile {:inline, format_module: 1, format_module1: 1, format_args: 1, format_pid: 1}
  defp format_module(module_atom), do: to_string(module_atom) |> format_module1()
  defp format_module1(<<"Elixir.", module_str::binary>>), do: module_str
  defp format_module1(module_str), do: ":" <> module_str
  defp format_args(arity) when is_integer(arity), do: "/#{arity}"

  defp format_args(args) when is_list(args) do
    arg_str = Enum.map(args, &inspect(&1, inspect_opts())) |> Enum.join(", ")
    "(" <> arg_str <> ")"
  end

  defp format_pid(pid), do: :io_lib.format(~c"~p", [pid]) |> to_string()

  @compile {:inline, calc_total_heap_size: 1}
  defp calc_total_heap_size(info) do
    info[:heap_size] + info[:old_heap_size] + info[:mbuf_size]
  end

  @compile {:inline, inspect_opts: 0}
  defp inspect_opts do
    opts = Application.get_env(:extrace, :inspect_opts, pretty: true)

    if :recon_map.is_active() do
      [{:inspect_fun, &Extrace.MapLimiter.limit_inspect/2} | opts]
    else
      opts
    end
  end
end
