defmodule LastFm.Refresh do
  use GenServer

  require Logger

  alias LastFm.{API, Feed}

  @refresh_interval System.convert_time_unit(30, :second, :millisecond)

  def start_link(config) do
    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end

  def init(config) do
    if config.api_key do
      {:ok, config, {:continue, :refresh}}
    else
      :ignore
    end
  end

  def handle_continue(:refresh, config) do
    case API.get_recent_tracks(config.user, config.api_key) do
      {:ok, tracks} ->
        Feed.update(tracks)
        Process.send_after(self(), :refresh, @refresh_interval)
        {:noreply, config}

      {:error, _reason} ->
        # TODO: think about failure scenario - error is logged at the API level
        Process.send_after(self(), :refresh, @refresh_interval)
        {:noreply, config}
    end
  end
end
