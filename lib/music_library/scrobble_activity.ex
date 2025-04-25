defmodule MusicLibrary.ScrobbleActivity do
  alias MusicLibrary.{Artists, Collection, Wishlist}

  def from_recent_tracks(recent_tracks, timezone) do
    localized_recent_tracks =
      Enum.map(recent_tracks, fn t ->
        %{
          t
          | scrobbled_at_label: localize_scrobbled_at(t.scrobbled_at_uts, timezone)
        }
      end)

    recent_release_ids = recent_release_ids(localized_recent_tracks)

    collected_releases = Collection.collected_releases(recent_release_ids)
    wishlisted_releases = Wishlist.wishlisted_releases(recent_release_ids)

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
