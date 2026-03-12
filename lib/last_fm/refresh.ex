defmodule LastFm.Refresh do
  @moduledoc """
  A GenServer that manages periodic refreshing of Last.fm scrobbled tracks.

  This module is responsible for:
  - Fetching recent tracks from Last.fm at configurable intervals
  - Updating an in-memory feed with the latest tracks
  - Supporting both automatic and manual refresh modes

  ## Configuration

  The server accepts a `LastFm.Config` struct with the following options:
  - `auto_refresh`: When true, automatically starts refreshing on init
  - `refresh_interval`: Time in milliseconds between refresh attempts

  ## Operation Modes

  1. Automatic Mode (`auto_refresh: true`):
     - Starts refreshing immediately on initialization
     - Continues to refresh at the configured interval
     - Handles failures gracefully by continuing to retry

  2. Manual Mode (`auto_refresh: false`):
     - Server remains dormant on initialization
     - Refreshes only occur via explicit `refresh/0` calls
     - Useful for testing or controlled refresh scenarios

  ## Usage

      # Manual refresh
      LastFm.Refresh.refresh()

  The module uses `LastFm.Feed` to store and broadcast track updates to subscribers.
  """

  use GenServer

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

      {:error, error} ->
        if API.ErrorResponse.retryable_error?(error) do
          {:noreply, config, API.ErrorResponse.retry_delay(error)}
        else
          {:stop, error, config}
        end
    end
  end
end
