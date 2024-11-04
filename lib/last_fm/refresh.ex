defmodule LastFm.Refresh do
  use GenServer

  require Logger

  alias LastFm.Feed

  @refresh_interval System.convert_time_unit(60, :second, :millisecond)

  def start_link(config) do
    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end

  @impl true
  def init(config) do
    if enabled?(config) do
      {:ok, config, {:continue, :refresh}}
    else
      :ignore
    end
  end

  @impl true
  def handle_continue(:refresh, config) do
    case config.api.get_recent_tracks(config.user, config.api_key) do
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

  @impl true
  def handle_info(:refresh, config) do
    case config.api.get_recent_tracks(config.user, config.api_key) do
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

  defp enabled?(config) do
    config.api && config.api_key
  end
end
