defmodule XTrace.SessionSupervisor do
  @moduledoc """
  DynamicSupervisor managing per-user `XTrace.Session` processes.

  Sessions are registered via `{:via, Registry, {XTrace.SessionRegistry, session_id}}`
  so they can be looked up by session_id.
  """
  use DynamicSupervisor

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @doc """
  Find or start a Session process for the given session_id.
  Returns `{:ok, pid}`.
  """
  @spec ensure_session(String.t()) :: {:ok, pid()} | {:error, term()}
  def ensure_session(session_id) do
    case find_session(session_id) do
      nil -> start_session(session_id)
      pid -> {:ok, pid}
    end
  end

  @doc """
  Start a new Session process for the given session_id.
  """
  @spec start_session(String.t()) :: {:ok, pid()} | {:error, term()}
  def start_session(session_id) do
    spec = {XTrace.Session, session_id}

    case DynamicSupervisor.start_child(__MODULE__, spec) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:ok, pid}
      error -> error
    end
  end

  @doc """
  Stop a Session process by session_id.
  """
  @spec stop_session(String.t()) :: :ok | {:error, :not_found}
  def stop_session(session_id) do
    case find_session(session_id) do
      nil -> {:error, :not_found}
      pid -> DynamicSupervisor.terminate_child(__MODULE__, pid)
    end
  end

  @doc """
  Find a Session process pid by session_id. Returns pid or nil.
  """
  @spec find_session(String.t()) :: pid() | nil
  def find_session(session_id) do
    case Registry.lookup(XTrace.SessionRegistry, session_id) do
      [{pid, _}] -> pid
      [] -> nil
    end
  end
end
