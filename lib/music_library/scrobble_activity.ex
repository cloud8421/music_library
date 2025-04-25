defmodule MusicLibrary.ScrobbleActivity do
  alias MusicLibrary.{Artists, Collection, Wishlist}

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

    "#{ldt.day}/#{ldt.month}/#{ldt.year} #{ldt.hour}:#{ldt.minute}"
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
