defmodule LastFm.Refresh do
  use GenServer

  require Logger

  alias LastFm.{API, Config, Feed}

  @type config :: Config.t()

  @spec start_link(config) :: GenServer.on_start()
  def start_link(config) do
    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end

  @spec refresh() :: :ok
  def refresh do
    GenServer.call(__MODULE__, :refresh, 10_000)
  end

  @impl true
  @spec init(config) :: {:ok, config, {:continue, :refresh}} | :ignore
  def init(config) do
    if config.auto_refresh do
      {:ok, config, {:continue, :refresh}}
    else
      :ignore
    end
  end

  @impl true
  @spec handle_call(:refresh, GenServer.from(), config) ::
          {:reply, :ok | {:error, term()}, config, pos_integer()}
  def handle_call(:refresh, _from, config) do
    case API.get_recent_tracks(config) do
      {:ok, tracks} ->
        Feed.update(tracks)
        {:reply, :ok, config, config.refresh_interval}

      error ->
        # TODO: think about failure scenario - error is logged at the API level
        {:reply, error, config, config.refresh_interval}
    end
  end

  @impl true
  @spec handle_continue(atom(), config) :: {:noreply, config, pos_integer()}
  def handle_continue(:refresh, config), do: refresh(config)

  @impl true
  @spec handle_info(atom(), config) :: {:noreply, config, pos_integer()}
  def handle_info(:refresh, config), do: refresh(config)

  def handle_info(:timeout, config), do: refresh(config)

  defp refresh(config) do
    case API.get_recent_tracks(config) do
      {:ok, tracks} ->
        Feed.update(tracks)
        {:noreply, config, config.refresh_interval}

      {:error, _reason} ->
        # TODO: think about failure scenario - error is logged at the API level
        {:noreply, config, config.refresh_interval}
    end
  end
end
