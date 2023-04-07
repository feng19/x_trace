defmodule XTrace do
  def main(_) do
    start()
    IO.puts("XTrace started.")

    receive do
      :stop -> :stop
    end
  end

  def start, do: Application.ensure_started(:x_trace)
end
