defmodule LastFm.Supervisor do
  use Supervisor

  def start_link(config) do
    Supervisor.start_link(__MODULE__, config, name: __MODULE__)
  end

  @impl true
  def init(config) do
    :ok = LastFm.Feed.create_table!()

    children = [
      {Finch, name: LastFm.Finch},
      {Phoenix.PubSub, name: LastFm.PubSub},
      {LastFm.Refresh, config}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
