defmodule XTrace.FormatHelper do
  @moduledoc false

  def format_t_specs(t_specs), do: Enum.map(t_specs, &inspect(&1, limit: :infinity))

  def format_rate_limiting(%{max: max, milliseconds: milliseconds}) do
    "{#{max}, #{milliseconds}}"
  end

  def format_rate_limiting(%{max: max}), do: to_string(max)

  def format_module(module) do
    case to_string(module) do
      "Elixir." <> m -> m
      m -> m
    end
  end

  def format_pids(pids) do
    Enum.map(pids, &inspect(&1, limit: :infinity))
  end

  def inspect_value(v) do
    inspect(v, pretty: true, limit: :infinity, width: 40)
  end
end
