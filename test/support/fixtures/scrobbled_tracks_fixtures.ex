defmodule MusicLibrary.ScrobbledTracksFixtures do
  @moduledoc """
  This module defines test helpers for creating
  scrobbled track entities via the database.
  """

  alias LastFm.Track
  alias MusicLibrary.Repo

  @doc """
  Generate a scrobbled track.
  """
  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  def track_fixture(attrs \\ %{}) do
    scrobbled_at_uts =
      attrs[:scrobbled_at_uts] || System.system_time(:second) - Enum.random(0..86_400)

    # Create map attributes for embedded schemas
    artist_attrs = %{
      musicbrainz_id: attrs[:artist_musicbrainz_id] || "",
      name: attrs[:artist_name] || "Test Artist"
    }

    album_attrs = %{
      musicbrainz_id: attrs[:album_musicbrainz_id] || "",
      title: attrs[:album_title] || "Test Album"
    }

    track_attrs = %{
      scrobbled_at_uts: scrobbled_at_uts,
      musicbrainz_id: attrs[:musicbrainz_id] || "",
      title: attrs[:title] || "Test Track",
      cover_url: attrs[:cover_url] || "https://example.com/cover.jpg",
      scrobbled_at_label: attrs[:scrobbled_at_label] || "01/01/2024 12:00:00",
      artist: artist_attrs,
      album: album_attrs,
      last_fm_data: attrs[:last_fm_data] || %{}
    }

    changeset = Track.changeset(%Track{}, track_attrs)
    {:ok, track} = Repo.insert(changeset)
    track
  end

  @doc """
  Generate a scrobbled track with nested artist/album maps.
  """
  def scrobbled_track_fixture(attrs \\ %{}) do
    default_attrs = %{
      scrobbled_at_uts: System.system_time(:second),
      musicbrainz_id: "track-mbid-12345",
      title: "Breathe",
      cover_url: "http://example.com/cover.jpg",
      scrobbled_at_label: "01 Jan 2023, 12:00",
      artist: %{
        musicbrainz_id: "",
        name: "Pink Floyd"
      },
      album: %{
        musicbrainz_id: "",
        title: "Dark Side of the Moon"
      },
      last_fm_data: %{}
    }

    attrs = Enum.into(attrs, default_attrs)

    %Track{}
    |> Track.changeset(attrs)
    |> Repo.insert!()
  end

  @doc """
  Generate multiple scrobbled tracks for testing pagination and search.
  """
  def create_test_tracks(count \\ 5) do
    artists = ["Pink Floyd", "The Beatles", "Led Zeppelin", "Queen", "The Rolling Stones"]
    albums = ["Dark Side", "Abbey Road", "IV", "A Night", "Sticky Fingers"]
    tracks = ["Money", "Come Together", "Stairway", "Bohemian", "Brown Sugar"]

    1..count
    |> Enum.map(fn i ->
      track_fixture(%{
        # 1 hour apart
        scrobbled_at_uts: System.system_time(:second) - i * 3600,
        title: Enum.at(tracks, rem(i - 1, length(tracks))) <> " #{i}",
        artist_name: Enum.at(artists, rem(i - 1, length(artists))),
        album_title: Enum.at(albums, rem(i - 1, length(albums))) <> " #{i}",
        scrobbled_at_label: "0#{rem(i, 9) + 1}/01/2024 1#{rem(i, 2)}:00:00"
      })
    end)
  end
end
