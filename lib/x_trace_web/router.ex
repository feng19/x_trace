defmodule XTraceWeb.Router do
  use XTraceWeb, :router
  import Phoenix.LiveDashboard.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {XTraceWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/", XTraceWeb do
    pipe_through :browser

    live "/", TraceLive
    live_dashboard "/dashboard", metrics: XTraceWeb.Telemetry
  end
end
