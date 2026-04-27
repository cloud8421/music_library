defmodule MusicLibrary.Chats.Supervisor do
  @moduledoc false
  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      {Registry, keys: :unique, name: MusicLibrary.Chats.SessionRegistry},
      {DynamicSupervisor, strategy: :one_for_one, name: Tune.Spotify.SessionSupervisor}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
