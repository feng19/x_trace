defmodule XTrace.Executor do
  @moduledoc """
  Remote trace executor. Runs on the remote node.

  Spawns a tracer process that:
  1. Creates a `trace` session with itself as the receiver
  2. Sets up trace patterns and flags
  3. Rate-limits trace messages via `XTrace.RateLimiter`
  4. Forwards allowed messages to the Session process on the local node
  """
  alias XTrace.{RateLimiter, Trace}

  @doc """
  Start tracing on this (remote) node.

  Called via RPC from `XTrace.Session` on the local node.
  Returns `{:ok, match_count, tracer_pid}` or `{:error, reason}`.
  """
  @spec start_trace(String.t(), pid(), list(), term(), list()) :: {:ok, non_neg_integer(), pid()} | {:error, term()}
  def start_trace(session_id, session_pid, t_specs, max, options) do
    parent = self()
    ref = make_ref()

    tracer =
      spawn(fn ->
        try do
          # Monitor the session process so we clean up if it dies
          Process.monitor(session_pid)

          rl = RateLimiter.from_max(max)
          {session, match_count} = Trace.start_trace(session_id, t_specs, options)
          send(parent, {ref, {:ok, match_count}})

          # Enter trace receiving loop
          tracer_loop(session, session_pid, rl)
        rescue
          e ->
            send(parent, {ref, {:error, Exception.message(e)}})
        catch
          error, reason ->
            send(parent, {ref, {:error, {error, reason}}})
        end
      end)

    receive do
      {^ref, {:ok, match_count}} ->
        {:ok, match_count, tracer}

      {^ref, {:error, reason}} ->
        {:error, reason}
    after
      5000 ->
        Process.exit(tracer, :kill)
        {:error, :timeout}
    end
  end

  @doc """
  Stop a remote tracer process.
  """
  @spec stop_trace(pid()) :: :ok
  def stop_trace(tracer_pid) do
    send(tracer_pid, :stop)
    :ok
  end

  # ===========================
  # Tracer Loop
  # ===========================

  defp tracer_loop(session, session_pid, rl) do
    receive do
      msg when is_tuple(msg) and elem(msg, 0) in [:trace, :trace_ts] ->
        case RateLimiter.check(rl) do
          {:ok, new_rl} ->
            send(session_pid, {:remote_trace, msg})
            tracer_loop(session, session_pid, new_rl)

          :rate_limited ->
            :trace.session_destroy(session)
            send(session_pid, :rate_limit_tripped)
            # Exit after rate limit
            :ok
        end

      :stop ->
        :trace.session_destroy(session)
        :ok

      {:DOWN, _ref, :process, _pid, _reason} ->
        :trace.session_destroy(session)
        :ok
    end
  end
end
