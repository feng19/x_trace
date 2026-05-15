defmodule XTrace.Session do
  @moduledoc """
  Per-user trace session GenServer.

  Each instance manages one trace session identified by a `session_id`
  (stored in the browser's HTTP cookie). It:

  1. Creates Erlang `trace` sessions via `trace:session_create/3`
  2. Receives trace messages as the tracer process
  3. Rate-limits via `XTrace.RateLimiter`
  4. Formats via `XTrace.Formatter`
  5. Broadcasts to PubSub on `topic(session_id)`
  6. Auto-terminates after 10 minutes of idle
  """
  use GenServer, restart: :temporary
  require Logger
  alias XTrace.{Formatter, RateLimiter, Trace}

  @idle_timeout_ms :timer.minutes(10)
  @type session_id :: String.t()

  # ===========================
  # Public API
  # ===========================

  @doc "PubSub topic for a session."
  @spec topic(session_id) :: String.t()
  def topic(session_id), do: "trace_session:#{session_id}"

  @doc "Broadcast an info message through the session's PubSub topic."
  @spec broadcast_session_info(session_id, String.t()) :: :ok
  def broadcast_session_info(session_id, message), do: broadcast(session_id, {:session_info, message})

  @doc false
  def broadcast(%{session_id: session_id}, message), do: broadcast(session_id, message)
  def broadcast(session_id, message), do: Phoenix.PubSub.broadcast(XTrace.PubSub, topic(session_id), message)

  @doc "Start the Session GenServer under the SessionSupervisor."
  def start_link(session_id) do
    GenServer.start_link(__MODULE__, session_id, name: {:via, Registry, {XTrace.SessionRegistry, session_id}})
  end

  @doc """
  Start tracing for the given session.

  Options:
  - `node` — remote node atom, or `nil` for local tracing
  - `t_specs` — list of `{module, fun, args}` trace specs
  - `max` — rate limit: integer (count) or `{count, ms}` (rate)
  - `options` — keyword list with `:scope`, `:pid`, `:timestamp`, `:args`, `:return_to`
  """
  @spec start_trace(session_id, list(), term(), keyword()) :: :ok | {:error, term()}
  def start_trace(session_id, t_specs, max, options \\ []) do
    GenServer.call(via(session_id), {:start_trace, t_specs, max, options}, 10_000)
  end

  @doc "Stop the current trace, keep the session alive (restarts idle timer)."
  @spec stop_trace(session_id) :: :ok
  def stop_trace(session_id) do
    GenServer.call(via(session_id), :stop_trace)
  end

  # ===========================
  # GenServer Callbacks
  # ===========================

  @doc "Register a LiveView process (on connected mount). The session monitors it and cancels idle while at least one is connected."
  @spec register_live_view(session_id) :: :ok
  def register_live_view(session_id) do
    GenServer.cast(via(session_id), {:register_live_view, self()})
  end

  @impl true
  def init(session_id) do
    state = %{
      session_id: session_id,
      trace_session: nil,
      rate_limiter: nil,
      idle_timer: nil,
      remote_node: nil,
      remote_tracer: nil,
      tracing?: false,
      live_views: %{}
    }

    # No LiveView connected yet — start idle timer
    {:ok, schedule_idle_timeout(state)}
  end

  @impl true
  def handle_call({:start_trace, t_specs, max, options}, _from, state) do
    # Stop any existing trace first
    state = do_stop_trace(state)
    state = cancel_idle_timeout(state)

    node = Keyword.get(options, :node)

    result =
      if node do
        start_remote_trace(state, node, t_specs, max, options)
      else
        start_local_trace(state, t_specs, max, options)
      end

    case result do
      {:ok, match_count, new_state} ->
        broadcast(new_state, {:session_info, format_calls_return(match_count)})
        {:reply, {:ok, match_count}, new_state}

      {:error, reason, new_state} ->
        broadcast(new_state, {:session_info, format_error(reason)})
        new_state = maybe_schedule_idle_timeout(new_state)
        {:reply, {:error, reason}, new_state}
    end
  end

  def handle_call(:stop_trace, _from, state) do
    state = do_stop_trace(state)
    broadcast(state, {:session_stopped, :manual})
    state = maybe_schedule_idle_timeout(state)
    {:reply, :ok, state}
  end

  @impl true
  def handle_cast({:register_live_view, pid}, state) do
    if Map.has_key?(state.live_views, pid) do
      # Already tracked — no-op
      {:noreply, state}
    else
      ref = Process.monitor(pid)
      state = %{state | live_views: Map.put(state.live_views, pid, ref)}
      # A LiveView is now connected — cancel any pending idle timer
      state = cancel_idle_timeout(state)
      {:noreply, state}
    end
  end

  @impl true
  # Local trace messages — this process is the tracer
  def handle_info(msg, state) when is_tuple(msg) and elem(msg, 0) in [:trace, :trace_ts] do
    handle_trace_msg(msg, state)
  end

  # Remote trace messages forwarded by Executor
  def handle_info({:remote_trace, trace_msg}, state) do
    # Already rate-limited by Executor — just format and broadcast
    formatted = Formatter.format(trace_msg)
    broadcast(state, {:trace_msg, formatted})
    {:noreply, state}
  end

  # Remote Executor rate limit tripped
  def handle_info(:rate_limit_tripped, state) do
    broadcast(state, {:session_info, "Rate limit tripped on remote node."})
    broadcast(state, {:session_stopped, :rate_limited})
    state = %{state | tracing?: false, remote_tracer: nil, rate_limiter: nil}
    {:noreply, maybe_schedule_idle_timeout(state)}
  end

  # Remote tracer process down
  def handle_info({:DOWN, _ref, :process, pid, reason}, %{remote_tracer: pid} = state) do
    if state.tracing? do
      broadcast(state, {:session_stopped, reason})
    end

    state = %{state | tracing?: false, remote_tracer: nil, rate_limiter: nil}
    {:noreply, maybe_schedule_idle_timeout(state)}
  end

  # LiveView process down — remove from tracked set, maybe start idle
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) when is_map_key(state.live_views, pid) do
    state = %{state | live_views: Map.delete(state.live_views, pid)}
    {:noreply, maybe_schedule_idle_timeout(state)}
  end

  # already stoped
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    {:noreply, maybe_schedule_idle_timeout(state)}
  end

  # Idle timeout
  def handle_info(:idle_timeout, state) do
    Logger.debug("Session #{state.session_id} idle timeout, terminating")
    {:stop, :normal, state}
  end

  def handle_info(msg, state) do
    Logger.warning("Session #{state.session_id} got unknown info: #{inspect(msg)}")
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, state) do
    do_stop_trace(state)
    :ok
  end

  # ===========================
  # Local Tracing
  # ===========================

  defp start_local_trace(state, t_specs, max, options) do
    rl = RateLimiter.from_max(max)
    {session, match_count} = Trace.start_trace(state.session_id, t_specs, options)

    new_state = %{
      state
      | trace_session: session,
        rate_limiter: rl,
        tracing?: true,
        remote_node: nil,
        remote_tracer: nil
    }

    {:ok, match_count, new_state}
  rescue
    e -> {:error, Exception.message(e), state}
  catch
    error, reason -> {:error, {error, reason}, state}
  end

  # ===========================
  # Remote Tracing
  # ===========================

  defp start_remote_trace(state, node, t_specs, max, options) do
    Trace.ensure_remote_modules(node)
    Trace.ensure_loaded(node, t_specs)

    case :rpc.call(node, XTrace.Executor, :start_trace, [state.session_id, self(), t_specs, max, options]) do
      {:ok, match_count, tracer_pid} ->
        Process.monitor(tracer_pid)

        new_state = %{
          state
          | tracing?: true,
            remote_node: node,
            remote_tracer: tracer_pid,
            rate_limiter: nil
        }

        {:ok, match_count, new_state}

      {:error, reason} ->
        {:error, reason, state}

      {:badrpc, reason} ->
        {:error, {:badrpc, reason}, state}
    end
  end

  # ===========================
  # Trace Message Handling
  # ===========================

  defp handle_trace_msg(msg, %{tracing?: true, rate_limiter: rl} = state) when not is_nil(rl) do
    case RateLimiter.check(rl) do
      {:ok, new_rl} ->
        formatted = Formatter.format(msg)
        broadcast(state, {:trace_msg, formatted})
        {:noreply, %{state | rate_limiter: new_rl}}

      :rate_limited ->
        # Destroy trace session, notify, enter idle
        destroy_trace_session(state)
        broadcast(state, {:session_info, "Rate limit tripped."})
        broadcast(state, {:session_stopped, :rate_limited})

        state = %{state | tracing?: false, trace_session: nil, rate_limiter: nil}
        {:noreply, maybe_schedule_idle_timeout(state)}
    end
  end

  defp handle_trace_msg(_msg, state) do
    # Not tracing or no rate limiter — discard
    {:noreply, state}
  end

  # ===========================
  # Stop / Cleanup
  # ===========================

  defp do_stop_trace(%{tracing?: false} = state), do: state

  defp do_stop_trace(state) do
    destroy_trace_session(state)
    stop_remote_tracer(state)
    %{state | tracing?: false, trace_session: nil, rate_limiter: nil, remote_tracer: nil}
  end

  defp destroy_trace_session(%{trace_session: nil}), do: :ok

  defp destroy_trace_session(%{trace_session: session}) do
    :trace.session_destroy(session)
  catch
    _, _ -> :ok
  end

  defp stop_remote_tracer(%{remote_tracer: nil}), do: :ok
  defp stop_remote_tracer(%{remote_node: nil}), do: :ok

  defp stop_remote_tracer(%{remote_node: node, remote_tracer: pid}) do
    :rpc.call(node, XTrace.Executor, :stop_trace, [pid])
  catch
    _, _ -> :ok
  end

  # ===========================
  # Idle Timeout
  # ===========================

  # Only schedule idle when no LiveView is connected and not actively tracing.
  defp maybe_schedule_idle_timeout(%{live_views: lv} = state) when map_size(lv) > 0, do: state
  defp maybe_schedule_idle_timeout(%{tracing?: true} = state), do: state
  defp maybe_schedule_idle_timeout(state), do: schedule_idle_timeout(state)

  defp schedule_idle_timeout(state) do
    state = cancel_idle_timeout(state)
    timer = Process.send_after(self(), :idle_timeout, @idle_timeout_ms)
    %{state | idle_timer: timer}
  end

  defp cancel_idle_timeout(%{idle_timer: nil} = state), do: state

  defp cancel_idle_timeout(%{idle_timer: timer} = state) do
    Process.cancel_timer(timer)
    %{state | idle_timer: nil}
  end

  # ===========================
  # Formatting Helpers
  # ===========================

  defp format_calls_return(0), do: "=> zero trace, calls failed!"
  defp format_calls_return(i) when is_integer(i), do: "=> #{i}, tracing..."

  defp format_error({:badrpc, reason}), do: "RPC error: #{inspect(reason)}"
  defp format_error(reason) when is_binary(reason), do: reason
  defp format_error(%{message: msg}), do: msg
  defp format_error(reason), do: inspect(reason)

  # ===========================
  # Registry Helper
  # ===========================

  defp via(session_id) do
    {:via, Registry, {XTrace.SessionRegistry, session_id}}
  end
end
