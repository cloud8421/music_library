defmodule MusicLibrary.ScrobbleActivity do
  alias LastFm.Scrobble
  alias MusicBrainz.Release
  alias MusicLibrary.{Artists, Collection, Wishlist}

  def scrobble(release_with_tracks, opts) when is_list(opts) do
    case opts do
      [started_at: _, finished_at: _] ->
        raise ArgumentError, """
        Cannot scobble a release with both started_at and finished_at.
          Remove either of them.
        """

      [started_at: started_at] ->
        scrobble(release_with_tracks, {:started_at, started_at})

      [finished_at: finished_at] ->
        scrobble(release_with_tracks, {:finished_at, finished_at})
    end
  end

  def scrobble(release_with_tracks, {:finished_at, finished_at}) do
    release_duration = Release.release_duration(release_with_tracks)
    started_at = DateTime.add(finished_at, -release_duration, :millisecond)
    scrobble(release_with_tracks, {:started_at, started_at})
  end

  def scrobble(release_with_tracks, {:started_at, started_at}) do
    session_key = MusicLibrary.Secrets.get!("last_fm_session_key").value

    {scrobbles, _finished_at} =
      release_with_tracks
      |> MusicBrainz.Release.tracks()
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

    LastFm.scrobble(scrobbles, session_key)
  end

  defp main_artist_name([]), do: nil
  defp main_artist_name([artist | _rest]), do: artist.name

  def from_recent_tracks(recent_tracks, timezone) do
    all_artist_pairs = Artists.get_all_artist_pairs()
    recent_release_ids = recent_release_ids(recent_tracks)
    collected_releases = Collection.collected_releases(recent_release_ids)
    wishlisted_releases = Wishlist.wishlisted_releases(recent_release_ids)

    localized_recent_tracks =
      Enum.map(recent_tracks, fn t ->
        %{
          t
          | scrobbled_at_label: localize_scrobbled_at(t.scrobbled_at_uts, timezone),
            artist: polyfill_artist(t, collected_releases, wishlisted_releases, all_artist_pairs)
        }
      end)

    all_artist_ids = Artists.get_all_artist_ids()
    recent_artist_ids = recent_artist_ids(localized_recent_tracks)
    artist_ids = MapSet.intersection(all_artist_ids, recent_artist_ids)

    recent_albums =
      localized_recent_tracks
      |> Enum.dedup_by(fn t -> t.album end)
      |> Enum.map(fn t ->
        %{
          scrobbled_at_uts: t.scrobbled_at_uts,
          scrobbled_at_label: t.scrobbled_at_label,
          metadata: t.album,
          artist: t.artist,
          cover_url: t.cover_url
        }
      end)

    %{
      localized_recent_tracks: localized_recent_tracks,
      localized_recent_albums: recent_albums,
      collected_releases: collected_releases,
      wishlisted_releases: wishlisted_releases,
      artist_ids: artist_ids
    }
  end

  defp polyfill_artist(track, collected_releases, wishlisted_releases, all_artist_pairs) do
    %{
      track.artist
      | musicbrainz_id:
          find_artist_id(track, collected_releases, wishlisted_releases, all_artist_pairs)
    }
  end

  defguardp has_no_artist_id(track)
            when is_nil(track.artist.musicbrainz_id) or track.artist.musicbrainz_id == ""

  defp find_artist_id(track, collected_releases, wishlisted_releases, all_artist_pairs)
       when has_no_artist_id(track) do
    matched_release =
      Enum.find(collected_releases ++ wishlisted_releases, fn r ->
        r.release_id == track.album.musicbrainz_id
      end)

    record_id = if matched_release, do: matched_release.record_id, else: nil

    if record_id do
      Enum.find_value(all_artist_pairs, fn pair ->
        if pair.record_id == record_id, do: pair.artist_id, else: nil
      end)
    else
      nil
    end
  end

  defp find_artist_id(track, _collected_releases, _wishlisted_releases, _all_artist_pairs) do
    track.artist.musicbrainz_id
  end

  defp localize_scrobbled_at(uts, timezone) do
    ldt =
      uts
      |> DateTime.from_unix!()
      |> DateTime.shift_zone!(timezone)

    Calendar.strftime(ldt, "%d/%m/%Y %X")
  end

  defp recent_release_ids(recent_tracks) do
    recent_tracks
    |> Enum.map(fn t -> t.album.musicbrainz_id end)
    |> Enum.uniq()
    |> Enum.reject(fn musicbrainz_id -> musicbrainz_id == "" end)
  end

  defp recent_artist_ids(recent_tracks) do
    recent_tracks
    |> Enum.map(fn t -> t.artist.musicbrainz_id end)
    |> Enum.uniq()
    |> Enum.reject(fn musicbrainz_id -> musicbrainz_id == "" end)
    |> MapSet.new()
  end
end
