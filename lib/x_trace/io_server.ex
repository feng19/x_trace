defmodule XTrace.IoServer do
  use GenServer

  @topic inspect(__MODULE__)

  def pid, do: Process.whereis(__MODULE__)
  def topic, do: @topic

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    {:ok, %{}}
  end

  def handle_info({:io_request, from, reply_as, request}, state) do
    msg =
      case request do
        {:put_chars, :unicode, chars} -> put_chars(chars)
        {:put_chars, :unicode, m, f, a} -> put_chars(m, f, a)
      end

    Phoenix.PubSub.broadcast(XTrace.PubSub, @topic, {:io_stream, msg})
    send(from, {:io_reply, reply_as, :ok})
    {:noreply, state}
  end

  def put_chars(chars), do: :unicode.characters_to_binary(chars)

  def put_chars(m, f, a) do
    apply(m, f, a) |> to_string()
  end
end
