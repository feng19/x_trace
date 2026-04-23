defmodule XTrace.Formatter do
  @moduledoc false
  alias XTrace.IoServer

  @spec format(trace_msg :: tuple) :: iodata
  def format(trace_msg) do
    msg = extract_info(trace_msg)
    Phoenix.PubSub.broadcast(XTrace.PubSub, IoServer.topic(), {:trace_msg, msg})
    :xtrace_ignore_me
  end

  @spec remote_format(io_server :: pid, trace_msg :: tuple) :: iodata
  def remote_format(io_server, trace_msg) do
    msg = extract_info(trace_msg)
    send(io_server, {:xtrace_msg, msg})
    :xtrace_ignore_me
  end

  def format_recall_cli(trace_info) when is_binary(trace_info) do
    Base.decode64!(trace_info) |> :erlang.binary_to_term() |> format_recall_cli()
  end

  def format_recall_cli([{m, f, arity}]) when is_integer(arity) do
    "#{format_module(m)}.#{f}/#{arity}"
  end

  def format_recall_cli([{m, f, args}]) do
    arg_str =
      Enum.map(args, &inspect(&1, width: :infinity, limit: :infinity, printable_limit: :infinity))
      |> Enum.join(", ")

    "#{format_module(m)}.#{f}(#{arg_str})"
  end

  def format_details(type, trace_info) when is_binary(trace_info) do
    trace_info = Base.decode64!(trace_info) |> :erlang.binary_to_term()

    case {type, trace_info} do
      {:receive, [msg]} ->
        [msg: msg]

      {:send, [msg, to]} ->
        [msg: msg, to: to]

      {:send_to_non_existing_process, [msg, to]} ->
        [msg: msg, to: to]

      {:call, [{_m, _f, args}]} ->
        args

      {:return_to, [{m, f, arity}]} ->
        [module: m, function: f, arity: arity]

      {:return_from, [{_m, _f, _arity}, return]} ->
        return

      {:exception_from, [{m, f, arity}, {class, val}]} ->
        [module: m, function: f, arity: arity, class: class, value: val]

      {:spawn, [spawned, {m, f, args}]} ->
        [spawned: spawned, module: m, function: f, args: args]

      {:exit, [reason]} ->
        [reason: reason]

      {:link, [linked]} ->
        [linked: linked]

      {:unlink, [linked]} ->
        [unlinked: linked]

      {:getting_linked, [linker]} ->
        [linker: linker]

      {:getting_unlinked, [unlinker]} ->
        [unlinker: unlinker]

      {:register, [name]} ->
        [name: name]

      {:unregister, [name]} ->
        [name: name]

      {:in, [{m, f, arity}]} ->
        [module: m, function: f, arity: arity]

      {:in, [0]} ->
        [info: :scheduled_in]

      {:out, [{m, f, arity}]} ->
        [module: m, function: f, arity: arity]

      {:out, [0]} ->
        [info: :scheduled_out]

      {:gc_start, [info]} ->
        [info: info]

      {:gc_end, [info]} ->
        [info: info]

      {_type, info} ->
        [raw: info]
    end
    |> inspect(pretty: true, width: 100, limit: :infinity, printable_limit: :infinity)
  end

  ###############
  ### Private ###
  ###############

  defp extract_info(trace_msg) do
    case :erlang.tuple_to_list(trace_msg) do
      [:trace_ts, pid, type | info] ->
        {trace_info, [timestamp]} = :lists.split(:erlang.length(info) - 1, info)
        content = format_body(type, trace_info)

        %{
          time: to_unixtime(timestamp),
          type: type,
          trace_info: encode_trace_info(trace_info),
          pid: format_pid(pid),
          content: content
        }

      [:trace, pid, type | trace_info] ->
        content = format_body(type, trace_info)

        %{
          time: System.system_time(),
          type: type,
          trace_info: encode_trace_info(trace_info),
          pid: format_pid(pid),
          content: content
        }
    end
  end

  defp encode_trace_info(trace_info), do: trace_info |> :erlang.term_to_binary() |> Base.encode64()

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

  defp format_body(:call, [{m, f, arity}]) when is_integer(arity) do
    "#{format_module(m)}.#{f}/#{arity}"
  end

  defp format_body(:call, [{m, f, args}]) do
    "#{format_module(m)}.#{f}(#{compact_format(args)})"
  end

  defp format_body(:return_to, [{m, f, arity}]) do
    "#{format_module(m)}.#{f}/#{arity}"
  end

  defp format_body(:return_from, [{m, f, arity}, return]) do
    "#{format_module(m)}.#{f}/#{arity} --> #{compact_format(return)}"
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

  @compile {:inline,
            format_module: 1, format_module1: 1, format_args: 1, format_pid: 1, compact_format: 1}
  defp format_module(module_atom), do: to_string(module_atom) |> format_module1()
  defp format_module1(<<"Elixir.", module_str::binary>>), do: module_str
  defp format_module1(module_str), do: ":" <> module_str
  defp format_args(arity) when is_integer(arity), do: "/#{arity}"

  defp format_args(args) when is_list(args) do
    arg_str = Enum.map(args, &inspect(&1, inspect_opts())) |> Enum.join(", ")
    "(" <> arg_str <> ")"
  end

  defp format_pid(pid), do: :io_lib.format(~c"~p", [pid]) |> to_string()

  defp compact_format(list) when is_list(list) do
    len = length(list)

    if len > 3 do
      "[#{len} items]"
    else
      items_str = Enum.map(list, &compact_format/1) |> Enum.join(", ")
      "[" <> items_str <> "]"
    end
  end

  defp compact_format(%{__struct__: struct_name} = struct) do
    fields = struct |> Map.from_struct() |> Map.to_list()
    len = length(fields)

    if len > 3 do
      "%#{format_module(struct_name)}{#{len} fields}"
    else
      fields_str =
        Enum.map(fields, fn {k, v} -> "#{k}: #{compact_format(v)}" end) |> Enum.join(", ")

      "%#{format_module(struct_name)}{" <> fields_str <> "}"
    end
  end

  defp compact_format(map) when is_map(map) do
    len = map_size(map)

    if len > 3 do
      "%{#{len} pairs}"
    else
      items_str =
        Enum.map(map, fn {k, v} ->
          if is_atom(k) do
            "#{k}: #{compact_format(v)}"
          else
            "#{compact_format(k)} => #{compact_format(v)}"
          end
        end)
        |> Enum.join(", ")

      "%{" <> items_str <> "}"
    end
  end

  defp compact_format(tuple) when is_tuple(tuple) do
    len = tuple_size(tuple)

    if len > 3 do
      "{#{len} elements}"
    else
      items_str = Tuple.to_list(tuple) |> Enum.map(&compact_format/1) |> Enum.join(", ")
      "{" <> items_str <> "}"
    end
  end

  defp compact_format(other), do: inspect(other, inspect_opts())

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
