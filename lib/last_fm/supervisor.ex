defmodule LastFm.Supervisor do
  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    :ok = LastFm.Feed.create_table!()

    children = [
      {Phoenix.PubSub, name: LastFm.PubSub},
      {LastFm.Refresh, %{api: api(), user: "cloud8421", api_key: api_key()}}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp api_key do
    Application.get_env(:music_library, LastFm, [])
    |> Keyword.get(:api_key)
  end

  defp api do
    Application.get_env(:music_library, :last_fm, LastFm.APIImpl)
  end
end
