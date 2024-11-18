defmodule LastFm.Refresh do
  use GenServer

  require Logger

  alias LastFm.Feed

  @type config :: %{
          api: module(),
          api_key: String.t(),
          user: String.t(),
          refresh_interval: pos_integer()
        }

  @spec start_link(config) :: GenServer.on_start()
  def start_link(config) do
    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end

  @spec refresh() :: :refresh
  def refresh do
    # TODO: Very barebones and naive - can be improved by building a state machine.
    send(__MODULE__, :refresh)
  end

  @impl true
  @spec init(config) :: {:ok, config, {:continue, :refresh}} | :ignore
  def init(config) do
    config = Map.new(config)

    if enabled?(config) do
      {:ok, config, {:continue, :refresh}}
    else
      :ignore
    end
  end

  @impl true
  @spec handle_continue(atom(), config) :: {:noreply, config}
  def handle_continue(:refresh, config), do: refresh(config)

  @impl true
  @spec handle_info(atom(), config) :: {:noreply, config}
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
