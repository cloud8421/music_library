defmodule MusicLibrary.Chats.Supervisor do
  @moduledoc false
  use Supervisor

  alias MusicLibrary.Chats.{Session, SessionRegistry, SessionSupervisor}

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      {Registry, keys: :unique, name: SessionRegistry},
      {DynamicSupervisor, strategy: :one_for_one, name: SessionSupervisor}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def ensure_session(params) do
    case start_session(params) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      error -> error
    end
  end

  defp start_session(params) do
    DynamicSupervisor.start_child(
      SessionSupervisor,
      {Session, params}
    )
  end
end
