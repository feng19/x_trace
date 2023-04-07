defmodule XTrace.Executor do
  @moduledoc false

  def calls(t_specs, max, options, io_server) do
    ref = make_ref()
    parent = self()

    spawn(fn ->
      :erlang.group_leader(io_server, self())
      :erlang.process_flag(:trap_exit, true)
      result = _calls(t_specs, max, options)
      send(parent, {ref, result})

      receive do
        {:EXIT, _pid, :normal} -> :ok
      end
    end)

    receive do
      {^ref, result} -> result
    end
  end

  defp _calls(t_specs, max, options) do
    case :code.is_loaded(Extrace) do
      {:file, _} ->
        Extrace.calls(t_specs, max, options)

      _ ->
        :recon_trace.calls(t_specs, max, options)
    end
  rescue
    reason ->
      {:error, reason, __STACKTRACE__}
  catch
    error, reason ->
      {error, reason, __STACKTRACE__}
  end
end
