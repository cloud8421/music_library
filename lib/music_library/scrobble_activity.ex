defmodule MusicLibrary.ScrobbleActivity do
  @moduledoc """
  Scrobbling releases, media, and tracks to Last.fm.
  """

  alias LastFm.Scrobble
  alias MusicBrainz.Release
  alias MusicLibrary.Secrets

  @spec can_scrobble?() :: boolean()
  def can_scrobble? do
    Secrets.get("last_fm_session_key") !== nil
  end

  @spec scrobble_release(map(), :started_at | :finished_at, DateTime.t()) ::
          {:ok, term()} | {:error, term()}
  def scrobble_release(release_with_tracks, :finished_at, finished_at) do
    release_duration = Release.release_duration(release_with_tracks)
    started_at = DateTime.add(finished_at, -release_duration, :millisecond)
    scrobble_release(release_with_tracks, :started_at, started_at)
  end

  def scrobble_release(release_with_tracks, :started_at, started_at) do
    release_duration = Release.release_duration(release_with_tracks)

    if release_duration == 0 do
      {:error, :no_duration}
    else
      with {:ok, session_key} <- fetch_session_key() do
        {scrobbles, _finished_at} =
          release_with_tracks
          |> MusicBrainz.Release.tracks()
          |> to_scrobbles(release_with_tracks, started_at)

        LastFm.scrobble(scrobbles, session_key)
      end
    end
  end

  @spec scrobble_medium(integer(), map(), :started_at | :finished_at, DateTime.t()) ::
          {:ok, term()} | {:error, term()}
  def scrobble_medium(number, release_with_tracks, :finished_at, finished_at) do
    case find_medium(release_with_tracks, number) do
      {:ok, medium} ->
        medium_duration = Release.medium_duration(medium)
        started_at = DateTime.add(finished_at, -medium_duration, :millisecond)
        scrobble_medium(number, release_with_tracks, :started_at, started_at)

      {:error, :medium_not_found} ->
        {:error, :medium_not_found}
    end
  end

  def scrobble_medium(number, release_with_tracks, :started_at, started_at) do
    case find_medium(release_with_tracks, number) do
      {:ok, medium} ->
        medium_duration = Release.medium_duration(medium)

        if medium_duration == 0 do
          {:error, :no_duration}
        else
          with {:ok, session_key} <- fetch_session_key() do
            {scrobbles, _finished_at} =
              medium.tracks
              |> to_scrobbles(release_with_tracks, started_at)

            LastFm.scrobble(scrobbles, session_key)
          end
        end

      {:error, :medium_not_found} ->
        {:error, :medium_not_found}
    end
  end

  @spec scrobble_tracks(MapSet.t(), map(), :started_at | :finished_at, DateTime.t()) ::
          {:ok, term()} | {:error, term()}
  def scrobble_tracks(selected_track_ids, release_with_tracks, :finished_at, finished_at) do
    all_tracks = Release.tracks(release_with_tracks)

    selected_tracks =
      Enum.filter(all_tracks, fn track -> MapSet.member?(selected_track_ids, track.id) end)

    tracks_duration = Enum.sum_by(selected_tracks, fn track -> track.length || 0 end)
    started_at = DateTime.add(finished_at, -tracks_duration, :millisecond)
    scrobble_tracks(selected_track_ids, release_with_tracks, :started_at, started_at)
  end

  def scrobble_tracks(selected_track_ids, release_with_tracks, :started_at, started_at) do
    all_tracks = Release.tracks(release_with_tracks)

    selected_tracks =
      Enum.filter(all_tracks, fn track -> MapSet.member?(selected_track_ids, track.id) end)

    tracks_duration = Enum.sum_by(selected_tracks, fn track -> track.length || 0 end)

    if tracks_duration == 0 do
      {:error, :no_duration}
    else
      with {:ok, session_key} <- fetch_session_key() do
        {scrobbles, _finished_at} =
          selected_tracks
          |> to_scrobbles(release_with_tracks, started_at)

        LastFm.scrobble(scrobbles, session_key)
      end
    end
  end

  defp fetch_session_key do
    case Secrets.get("last_fm_session_key") do
      %{value: value} -> {:ok, value}
      nil -> {:error, :no_session_key}
    end
  end

  defp to_scrobbles(tracks, release_with_tracks, started_at) do
    tracks
    |> Enum.map_reduce(started_at, fn track, time ->
      album_artist =
        if release_with_tracks.artists !== track.artists do
          main_artist_name(release_with_tracks.artists)
        end

      time = time |> DateTime.add(track.length, :millisecond)

      scrobble = %Scrobble{
        artist: main_artist_name(track.artists),
        album: release_with_tracks.title,
        album_artist: album_artist,
        track: track.title,
        timestamp: DateTime.to_unix(time)
      }

      {scrobble, time}
    end)
  end

  defp find_medium(release_with_tracks, number) do
    case Enum.find(release_with_tracks.media, fn medium -> medium.number == number end) do
      nil -> {:error, :medium_not_found}
      medium -> {:ok, medium}
    end
  end

  defp main_artist_name([]), do: nil
  defp main_artist_name([artist | _rest]), do: artist.name
end
