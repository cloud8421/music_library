defmodule MusicLibrary.ListeningStats.Refresh do
  @moduledoc """
  A GenServer that manages periodic refreshing of Last.fm scrobbled tracks.

  Fetches recent tracks from Last.fm at configurable intervals and persists
  them via `MusicLibrary.ListeningStats.update/1`.

  ## Configuration

  Accepts a tuple of `{LastFm.Config.t(), keyword()}` where the keyword list contains:
  - `auto_refresh` — when true, automatically starts refreshing on init
  - `refresh_interval` — time in milliseconds between refresh attempts

  ## Operation Modes

  1. Automatic Mode (`auto_refresh: true`):
     - Starts refreshing immediately on initialization
     - Continues to refresh at the configured interval
     - Handles failures gracefully by continuing to retry

  2. Manual Mode (`auto_refresh: false`):
     - Server remains dormant on initialization
     - Refreshes only occur via explicit `refresh/0` calls
  """

  use GenServer

  alias LastFm.{API, Config}
  alias MusicLibrary.ListeningStats

  @type state :: %{
          api_config: Config.t(),
          auto_refresh: boolean(),
          refresh_interval: pos_integer()
        }

  @spec start_link({Config.t(), keyword()}) :: GenServer.on_start()
  def start_link({api_config, refresh_opts}) do
    state = %{
      api_config: api_config,
      auto_refresh: Keyword.get(refresh_opts, :auto_refresh, true),
      refresh_interval: Keyword.get(refresh_opts, :refresh_interval, 60_000)
    }

    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  @spec refresh() :: :ok
  def refresh do
    GenServer.call(__MODULE__, :refresh, 10_000)
  end

  @impl true
  @spec init(state) :: {:ok, state, {:continue, :refresh}} | :ignore
  def init(state) do
    if state.auto_refresh do
      {:ok, state, {:continue, :refresh}}
    else
      :ignore
    end
  end

  @impl true
  @spec handle_call(:refresh, GenServer.from(), state) ::
          {:reply, :ok | {:error, term()}, state, pos_integer()}
  def handle_call(:refresh, _from, state) do
    case API.get_recent_tracks(state.api_config) do
      {:ok, tracks} ->
        ListeningStats.update(tracks)
        {:reply, :ok, state, state.refresh_interval}

      error ->
        {:reply, error, state, state.refresh_interval}
    end
  end

  @impl true
  @spec handle_continue(atom(), state) :: {:noreply, state, pos_integer()}
  def handle_continue(:refresh, state), do: do_refresh(state)

  @impl true
  @spec handle_info(atom(), state) :: {:noreply, state, pos_integer()}
  def handle_info(:refresh, state), do: do_refresh(state)

  def handle_info(:timeout, state), do: do_refresh(state)

  defp do_refresh(state) do
    case API.get_recent_tracks(state.api_config) do
      {:ok, tracks} ->
        ListeningStats.update(tracks)
        {:noreply, state, state.refresh_interval}

      {:error, error} ->
        if API.ErrorResponse.retryable_error?(error) do
          {:noreply, state, API.ErrorResponse.retry_delay(error)}
        else
          {:stop, error, state}
        end
    end
  end
end
