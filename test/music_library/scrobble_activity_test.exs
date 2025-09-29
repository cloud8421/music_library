defmodule MusicLibrary.ScrobbleActivityTest do
  use MusicLibrary.DataCase

  import MusicLibrary.ScrobbledTracksFixtures

  alias LastFm.Track
  alias MusicLibrary.ScrobbleActivity

  describe "list_tracks/1" do
    test "returns all tracks when no parameters provided" do
      _track1 = track_fixture(%{title: "First Track"})
      _track2 = track_fixture(%{title: "Second Track"})

      tracks = list_tracks()

      assert length(tracks) == 2
      track_titles = Enum.map(tracks, & &1.title)
      assert "First Track" in track_titles
      assert "Second Track" in track_titles
    end

    test "returns tracks ordered by scrobbled_at_uts by default" do
      _older_track =
        track_fixture(%{
          title: "Older Track",
          scrobbled_at_uts: System.system_time(:second) - 3600
        })

      _newer_track =
        track_fixture(%{
          title: "Newer Track",
          scrobbled_at_uts: System.system_time(:second)
        })

      tracks = list_tracks(%{order: :scrobbled_at})

      assert length(tracks) == 2
      # Should be ordered by scrobbled_at_uts descending (newest first)
      assert List.first(tracks).title == "Newer Track"
      assert List.last(tracks).title == "Older Track"
    end

    test "returns tracks ordered by title" do
      track_fixture(%{title: "Zebra Track"})
      track_fixture(%{title: "Alpha Track"})

      tracks = list_tracks(%{order: :title})

      assert length(tracks) == 2
      assert List.first(tracks).title == "Alpha Track"
      assert List.last(tracks).title == "Zebra Track"
    end

    test "returns tracks ordered by artist name" do
      track_fixture(%{artist_name: "Zebra Artist", title: "Track 1"})
      track_fixture(%{artist_name: "Alpha Artist", title: "Track 2"})

      tracks = list_tracks(%{order: :artist})

      assert length(tracks) == 2
      assert List.first(tracks).artist.name == "Alpha Artist"
      assert List.last(tracks).artist.name == "Zebra Artist"
    end

    test "returns tracks ordered by album title" do
      track_fixture(%{album_title: "Zebra Album", title: "Track 1"})
      track_fixture(%{album_title: "Alpha Album", title: "Track 2"})

      tracks = list_tracks(%{order: :album})

      assert length(tracks) == 2
      assert List.first(tracks).album.title == "Alpha Album"
      assert List.last(tracks).album.title == "Zebra Album"
    end

    test "filters tracks by search query matching track title" do
      track_fixture(%{title: "Special Track"})
      track_fixture(%{title: "Regular Track"})

      tracks = list_tracks(%{query: "Special"})

      assert length(tracks) == 1
      assert List.first(tracks).title == "Special Track"
    end

    test "filters tracks by search query matching artist name" do
      track_fixture(%{artist_name: "Special Artist", title: "Track 1"})
      track_fixture(%{artist_name: "Regular Artist", title: "Track 2"})

      tracks = list_tracks(%{query: "Special Artist"})

      assert length(tracks) == 1
      assert List.first(tracks).artist.name == "Special Artist"
    end

    test "filters tracks by search query matching album title" do
      track_fixture(%{album_title: "Special Album", title: "Track 1"})
      track_fixture(%{album_title: "Regular Album", title: "Track 2"})

      tracks = list_tracks(%{query: "Special Album"})

      assert length(tracks) == 1
      assert List.first(tracks).album.title == "Special Album"
    end

    test "applies pagination correctly" do
      create_test_tracks(5)

      # Get first 2 tracks
      tracks_page_1 = list_tracks(%{page: 1, page_size: 2})
      assert length(tracks_page_1) == 2

      # Get next 2 tracks
      tracks_page_2 = list_tracks(%{page: 2, page_size: 2})
      assert length(tracks_page_2) == 2

      # Ensure they're different tracks
      page_1_ids = Enum.map(tracks_page_1, & &1.scrobbled_at_uts)
      page_2_ids = Enum.map(tracks_page_2, & &1.scrobbled_at_uts)
      assert Enum.empty?(page_1_ids -- (page_1_ids -- page_2_ids))
    end

    test "returns empty list when query matches no tracks" do
      track_fixture(%{title: "Test Track"})

      tracks = list_tracks(%{query: "NonexistentTrack"})

      assert tracks == []
    end
  end

  describe "get_track!/1" do
    test "returns the track with given scrobbled_at_uts as integer" do
      track = track_fixture()

      found_track = ScrobbleActivity.get_track!(track.scrobbled_at_uts)

      assert found_track.scrobbled_at_uts == track.scrobbled_at_uts
      assert found_track.title == track.title
    end

    test "returns the track with given scrobbled_at_uts as string" do
      track = track_fixture()

      found_track = ScrobbleActivity.get_track!(to_string(track.scrobbled_at_uts))

      assert found_track.scrobbled_at_uts == track.scrobbled_at_uts
    end

    test "raises Ecto.NoResultsError when track does not exist" do
      assert_raise Ecto.NoResultsError, fn ->
        ScrobbleActivity.get_track!(999_999_999)
      end
    end

    test "raises Ecto.NoResultsError when given invalid string" do
      assert_raise Ecto.NoResultsError, fn ->
        ScrobbleActivity.get_track!("invalid")
      end
    end
  end

  describe "update_track/2" do
    test "updates the track with valid attributes" do
      track = track_fixture(%{title: "Original Title"})

      update_attrs = %{
        title: "Updated Title",
        artist: %{name: "Updated Artist"},
        album: %{title: "Updated Album"}
      }

      assert {:ok, updated_track} = ScrobbleActivity.update_track(track, update_attrs)
      assert updated_track.title == "Updated Title"
      assert updated_track.artist.name == "Updated Artist"
      assert updated_track.album.title == "Updated Album"
    end

    test "returns error changeset with invalid attributes" do
      track = track_fixture()

      invalid_attrs = %{title: ""}

      assert {:error, %Ecto.Changeset{}} = ScrobbleActivity.update_track(track, invalid_attrs)
    end

    test "updates scrobbled_at_label" do
      track = track_fixture(%{scrobbled_at_label: "01/01/2024 12:00:00"})

      update_attrs = %{scrobbled_at_label: "02/02/2024 14:30:00"}

      assert {:ok, updated_track} = ScrobbleActivity.update_track(track, update_attrs)
      assert updated_track.scrobbled_at_label == "02/02/2024 14:30:00"
    end

    test "updates cover_url" do
      track = track_fixture(%{cover_url: "https://example.com/old.jpg"})

      update_attrs = %{cover_url: "https://example.com/new.jpg"}

      assert {:ok, updated_track} = ScrobbleActivity.update_track(track, update_attrs)
      assert updated_track.cover_url == "https://example.com/new.jpg"
    end
  end

  describe "delete_track/1" do
    test "deletes the track" do
      track = track_fixture()

      assert {:ok, %Track{}} = ScrobbleActivity.delete_track(track)

      assert_raise Ecto.NoResultsError, fn ->
        ScrobbleActivity.get_track!(track.scrobbled_at_uts)
      end
    end

    test "returns error when track has already been deleted" do
      track = track_fixture()
      {:ok, _} = ScrobbleActivity.delete_track(track)

      # Attempt to delete again should fail
      assert_raise Ecto.StaleEntryError, fn ->
        ScrobbleActivity.delete_track(track)
      end
    end
  end

  describe "search_tracks_count/1" do
    test "returns total count when no query provided" do
      create_test_tracks(3)

      count = ScrobbleActivity.search_tracks_count()

      assert count == 3
    end

    test "returns filtered count when query provided" do
      track_fixture(%{title: "Special Track"})
      track_fixture(%{title: "Regular Track"})
      track_fixture(%{title: "Another Track"})

      count = ScrobbleActivity.search_tracks_count("Special")

      assert count == 1
    end

    test "returns zero when query matches no tracks" do
      track_fixture(%{title: "Test Track"})

      count = ScrobbleActivity.search_tracks_count("Nonexistent")

      assert count == 0
    end

    test "counts tracks matching artist name" do
      track_fixture(%{artist_name: "Special Artist", title: "Track 1"})
      track_fixture(%{artist_name: "Regular Artist", title: "Track 2"})

      count = ScrobbleActivity.search_tracks_count("Special")

      assert count == 1
    end

    test "counts tracks matching album title" do
      track_fixture(%{album_title: "Special Album", title: "Track 1"})
      track_fixture(%{album_title: "Regular Album", title: "Track 2"})

      count = ScrobbleActivity.search_tracks_count("Special")

      assert count == 1
    end
  end

  describe "integration with existing functions" do
    test "scrobble_count returns correct count" do
      initial_count = ScrobbleActivity.scrobble_count()

      create_test_tracks(3)

      new_count = ScrobbleActivity.scrobble_count()

      assert new_count == initial_count + 3
    end
  end

  defp list_tracks do
    ScrobbleActivity.list_tracks()
    |> Enum.map(fn r -> r.track end)
  end

  defp list_tracks(params) do
    ScrobbleActivity.list_tracks(params)
    |> Enum.map(fn r -> r.track end)
  end
end
