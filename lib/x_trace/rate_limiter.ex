defmodule XTrace.RateLimiter do
  @moduledoc """
  Pure functional rate limiter for trace messages.

  Two modes:
  - **Count mode** (`new/1`): Allow at most N messages total, then stop.
  - **Rate mode** (`new/2`): Allow at most N messages per time window (ms).
    Resets when the window elapses. Stops when exceeded within a window.

  This module is a pure data structure + functions with no process coupling.
  It can be used in Session (local tracing) or Executor (remote tracing).
  """

  @enforce_keys [:mode, :max]
  defstruct [:mode, :max, :time_ms, :window_start, count: 0]

  @type t :: %__MODULE__{
          mode: :count | :rate,
          max: pos_integer(),
          time_ms: non_neg_integer() | nil,
          count: non_neg_integer(),
          window_start: integer() | nil
        }

  @doc """
  Create a count-based rate limiter. Allows `max` messages total.
  """
  @spec new(pos_integer()) :: t()
  def new(max) when is_integer(max) and max > 0 do
    %__MODULE__{mode: :count, max: max, count: 0}
  end

  @doc """
  Create a rate-based rate limiter. Allows `max` messages per `time_ms` window.
  """
  @spec new(pos_integer(), pos_integer()) :: t()
  def new(max, time_ms) when is_integer(max) and max > 0 and is_integer(time_ms) and time_ms > 0 do
    %__MODULE__{
      mode: :rate,
      max: max,
      time_ms: time_ms,
      count: 0,
      window_start: now_ms()
    }
  end

  @doc """
  Create a rate limiter from the UI's max format.

  - `{max, time_ms}` → rate mode
  - `max` (integer) → count mode
  """
  @spec from_max(pos_integer() | {pos_integer(), pos_integer()}) :: t()
  def from_max({max, time_ms}) when is_integer(max) and is_integer(time_ms), do: new(max, time_ms)
  def from_max(max) when is_integer(max), do: new(max)

  @doc """
  Check whether a message should be allowed through.

  Returns `{:ok, updated_state}` if allowed, or `:rate_limited` if the limit
  has been reached.
  """
  @spec check(t()) :: {:ok, t()} | :rate_limited
  def check(%__MODULE__{mode: :count, count: count, max: max}) when count >= max do
    :rate_limited
  end

  def check(%__MODULE__{mode: :count} = state) do
    {:ok, %{state | count: state.count + 1}}
  end

  def check(%__MODULE__{mode: :rate} = state) do
    now = now_ms()
    elapsed = now - state.window_start

    cond do
      elapsed >= state.time_ms ->
        # Window expired — reset counter, start new window
        {:ok, %{state | count: 1, window_start: now}}

      state.count < state.max ->
        # Within window and under limit
        {:ok, %{state | count: state.count + 1}}

      true ->
        # Within window but at/over limit
        :rate_limited
    end
  end

  defp now_ms, do: System.monotonic_time(:millisecond)
end
