defmodule XTrace.Executor do
  @moduledoc false

  def calls(t_specs, max, options, io_server) do
    spawn(fn ->
      :erlang.group_leader(io_server, self())
      :erlang.process_flag(:trap_exit, true)

      case :code.is_loaded(Extrace) do
        {:file, _} ->
          Extrace.calls(t_specs, max, options)

        _ ->
          :recon_trace.calls(t_specs, max, options)
      end

      receive do
        {:EXIT, _pid, :normal} -> :ok
      end
    end)
  end
end
