defmodule LastFm.Refresh do
  use GenServer

  require Logger

  alias LastFm.Feed

  def start_link(config) do
    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end

  @impl true
  def init(config) do
    config = Map.new(config)

    if enabled?(config) do
      {:ok, config, {:continue, :refresh}}
    else
      :ignore
    end
  end

  @impl true
  def handle_continue(:refresh, config), do: refresh(config)

  @impl true
  def handle_info(:refresh, config), do: refresh(config)

  defp refresh(config) do
    case config.api.get_recent_tracks(config.user, config.api_key) do
      {:ok, tracks} ->
        Feed.update(tracks)
        Process.send_after(self(), :refresh, config.refresh_interval)
        {:noreply, config}

      {:error, _reason} ->
        # TODO: think about failure scenario - error is logged at the API level
        Process.send_after(self(), :refresh, config.refresh_interval)
        {:noreply, config}
    end
  end

  defp enabled?(config) do
    config.api && config.api_key
  end
end
