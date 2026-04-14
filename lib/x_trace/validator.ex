defmodule XTrace.Validator do
  @moduledoc false
  alias XTrace.TraceHelper

  def validate_rate_limiting(max, milliseconds) do
    case check_integer(max) do
      {:ok, max} when max < 1 ->
        {:error, "rate-limiting max too small, right in 1..1000"}

      {:ok, max} when max > 1000 ->
        {:error, "rate-limiting max too big, right in 1..1000"}

      {:ok, max} ->
        case String.trim(milliseconds) do
          "" ->
            {:ok, %{max: max}}

          _ ->
            case check_integer(milliseconds) do
              {:ok, milliseconds} when milliseconds < 100 ->
                {:error, "rate-limiting milliseconds too small, right in 100..10000"}

              {:ok, milliseconds} when milliseconds > 10000 ->
                {:error, "rate-limiting milliseconds too big, right in 100..10000"}

              {:ok, milliseconds} ->
                {:ok, %{max: max, milliseconds: milliseconds}}

              {:error, error} ->
                {:error, "rate-limiting milliseconds #{error}"}
            end
        end

      {:error, error} ->
        {:error, "rate-limiting max #{error}"}
    end
  end

  def validate_pid(pid, node_info) do
    pid = :recon_lib.term_to_pid("<#{pid}>")

    if node_info.is_self do
      Process.alive?(pid)
    else
      TraceHelper.call(node_info.connected_node, :erlang, :is_process_alive, [pid])
    end
    |> if do
      {:ok, pid}
    else
      {:error, "pid not alive"}
    end
  catch
    _, _ -> {:error, "bad pid"}
  end

  def check_integer(params, key) do
    params |> Map.get(key) |> check_integer()
  end

  def check_integer(value) do
    case String.trim(value) do
      "" ->
        {:error, "empty, please type integer"}

      value ->
        case Integer.parse(value) do
          {int, _} -> {:ok, int}
          :error -> {:error, "invalid value, please type integer"}
        end
    end
  end
end
