defmodule XTraceWeb.Router do
  use XTraceWeb, :router
  import Phoenix.LiveDashboard.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :ensure_trace_session_id
    plug :fetch_live_flash
    plug :put_root_layout, html: {XTraceWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  # Ensure every browser session has a trace_session_id for Session process lookup
  defp ensure_trace_session_id(conn, _opts) do
    case Plug.Conn.get_session(conn, "trace_session_id") do
      nil ->
        id = Base.url_encode64(:crypto.strong_rand_bytes(16))
        Plug.Conn.put_session(conn, "trace_session_id", id)

      _ ->
        conn
    end
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", XTraceWeb do
    pipe_through :browser

    live "/", TraceLive
    live_dashboard "/dashboard", metrics: XTraceWeb.Telemetry
  end
end
