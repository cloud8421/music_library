defmodule MusicLibrary.Records.SimilarityTest do
  use MusicLibrary.DataCase

  import MusicLibrary.ArtistInfoFixtures
  import MusicLibrary.Fixtures.Records

  alias MusicLibrary.Records.{Record, Similarity}

  describe "text_representation/1" do
    test "generates text representation for a record" do
      record = %Record{
        title: "OK Computer",
        artists: [
          %{
            name: "Radiohead",
            sort_name: "Radiohead",
            musicbrainz_id: "a74b1b7f-71a5-4011-9441-d0b5e4122711",
            disambiguation: "",
            joinphrase: ""
          }
        ],
        genres: ["alternative rock", "art rock", "experimental"],
        release_date: "1997-05-21",
        type: :album
      }

      text = Similarity.text_representation(record)

      assert text =~ "Album: OK Computer"
      assert text =~ "Artists: Radiohead"
      assert text =~ "Genres: alternative rock, art rock, experimental"
      assert text =~ "Released: 1997"
      assert text =~ "Type: Album"
    end

    test "includes Wikipedia data when available" do
      artist_info =
        artist_info_fixture(%{
          musicbrainz_data: %{"name" => "Radiohead"},
          wikipedia_data: %{
            "description" => "English rock band",
            "extract" =>
              "Radiohead are an English rock band formed in Abingdon. They are known for experimental music."
          }
        })

      record = %Record{
        title: "OK Computer",
        artists: [
          %{
            name: "Radiohead",
            sort_name: "Radiohead",
            musicbrainz_id: artist_info.id,
            disambiguation: "",
            joinphrase: ""
          }
        ],
        genres: ["alternative rock"],
        release_date: "1997-05-21",
        type: :album
      }

      text = Similarity.text_representation(record)

      assert text =~ "English rock band"
      assert text =~ "experimental music"
      refute text =~ "Members"
    end

    test "falls back to truncated Discogs profile when Wikipedia unavailable" do
      artist_info =
        artist_info_fixture(%{
          musicbrainz_data: %{"name" => "Some Artist"},
          discogs_data: %{
            "name" => "Some Artist",
            "profile_plaintext" => "Some Artist is a funk band. They have released many albums.",
            "members" => [%{"name" => "Member One"}, %{"name" => "Member Two"}]
          }
        })

      record = %Record{
        title: "Funky Album",
        artists: [
          %{
            name: "Some Artist",
            sort_name: "Some Artist",
            musicbrainz_id: artist_info.id,
            disambiguation: "",
            joinphrase: ""
          }
        ],
        genres: ["funk"],
        release_date: "2000",
        type: :album
      }

      text = Similarity.text_representation(record)

      assert text =~ "funk band"
      refute text =~ "Members"
      refute text =~ "Member One"
    end

    test "handles records with no release date" do
      record = %Record{
        title: "Unknown Album",
        artists: [
          %{
            name: "Artist",
            sort_name: "Artist",
            musicbrainz_id: "id",
            disambiguation: "",
            joinphrase: ""
          }
        ],
        genres: ["rock"],
        release_date: nil,
        type: :album
      }

      text = Similarity.text_representation(record)

      assert text =~ "Released: Unknown"
    end

    test "handles different record types" do
      record = %Record{
        title: "Live at Budokan",
        artists: [
          %{
            name: "Cheap Trick",
            sort_name: "Cheap Trick",
            musicbrainz_id: "id",
            disambiguation: "",
            joinphrase: ""
          }
        ],
        genres: ["rock"],
        release_date: "1979",
        type: :live
      }

      text = Similarity.text_representation(record)

      assert text =~ "Type: Live"
    end

    test "handles multiple artists" do
      record = %Record{
        title: "Collaboration Album",
        artists: [
          %{
            name: "Artist One",
            sort_name: "One, Artist",
            musicbrainz_id: "id1",
            disambiguation: "",
            joinphrase: " & "
          },
          %{
            name: "Artist Two",
            sort_name: "Two, Artist",
            musicbrainz_id: "id2",
            disambiguation: "",
            joinphrase: ""
          }
        ],
        genres: ["electronic"],
        release_date: "2020-01-01",
        type: :album
      }

      text = Similarity.text_representation(record)

      # Record.artist_names joins with ", " not with joinphrase
      assert text =~ "Artists: Artist One, Artist Two"
    end
  end

  describe "truncate_to_sentence/2" do
    test "returns text unchanged when within limit" do
      assert Similarity.truncate_to_sentence("Short text.", 200) == "Short text."
    end

    test "truncates at sentence boundary" do
      text = "First sentence. Second sentence. Third sentence that is very long."

      result = Similarity.truncate_to_sentence(text, 40)

      assert result == "First sentence. Second sentence."
    end

    test "truncates at character limit when no sentence boundary" do
      text = String.duplicate("a", 300)

      result = Similarity.truncate_to_sentence(text, 200)

      assert byte_size(result) <= 200
    end

    test "handles empty string" do
      assert Similarity.truncate_to_sentence("", 200) == ""
    end

    test "handles text with exclamation and question marks" do
      text = "What a band! They play great music? Yes indeed. More text that goes over the limit."

      result = Similarity.truncate_to_sentence(text, 55)

      assert result == "What a band! They play great music? Yes indeed."
    end
  end

  describe "store_embedding/3 and get_embedding/1" do
    test "stores and retrieves an embedding" do
      record = record()
      embedding = Enum.map(1..1536, fn _ -> :rand.uniform() end)
      text_rep = "Test representation"

      assert {:ok, _} = Similarity.store_embedding(record.id, embedding, text_rep)
      assert {:ok, retrieved_embedding} = Similarity.get_embedding(record.id)

      assert SqliteVec.Float32.new(embedding) == retrieved_embedding
    end

    test "updates existing embedding on conflict" do
      record = record()
      embedding1 = Enum.map(1..1536, fn _ -> 0.5 end)
      embedding2 = Enum.map(1..1536, fn _ -> 0.7 end)

      assert {:ok, _} = Similarity.store_embedding(record.id, embedding1, "Text 1")
      assert {:ok, _} = Similarity.store_embedding(record.id, embedding2, "Text 2")

      assert {:ok, retrieved_embedding} = Similarity.get_embedding(record.id)
      assert SqliteVec.Float32.new(embedding2) == retrieved_embedding
    end

    test "returns error for non-existent record" do
      assert {:error, :not_found} = Similarity.get_embedding(Ecto.UUID.generate())
    end
  end

  describe "find_similar/2" do
    setup do
      # Create test records with embeddings
      record1 = record(%{title: "Rock Album 1", genres: ["rock", "alternative"]})
      record2 = record(%{title: "Rock Album 2", genres: ["rock", "indie"]})
      record3 = record(%{title: "Jazz Album", genres: ["jazz", "fusion"]})

      # Create similar embeddings for rock albums and different for jazz
      rock_embedding_base = Enum.map(1..1536, fn i -> if i <= 10, do: 1.0, else: 0.0 end)
      jazz_embedding = Enum.map(1..1536, fn i -> if i > 1526, do: 1.0, else: 0.0 end)

      # Slight variation for record2
      rock_embedding2 = List.update_at(rock_embedding_base, 5, fn _ -> 0.9 end)

      Similarity.store_embedding(record1.id, rock_embedding_base, "Rock 1")
      Similarity.store_embedding(record2.id, rock_embedding2, "Rock 2")
      Similarity.store_embedding(record3.id, jazz_embedding, "Jazz")

      %{record1: record1, record2: record2, record3: record3}
    end

    test "finds similar records", %{record1: record1, record2: record2} do
      similar = Similarity.find_similar(record1.id, limit: 5, max_distance: 1.0)

      refute Enum.empty?(similar)
      # record2 should be most similar to record1
      %{record: first_record, similarity: similarity} = List.first(similar)
      assert first_record.id == record2.id
      assert similarity < 5.0
    end

    test "respects limit option", %{record1: record1} do
      similar = Similarity.find_similar(record1.id, limit: 1, max_distance: 1.0)

      assert length(similar) == 1
    end

    test "returns empty list for record without embedding" do
      record_without_embedding = record()

      similar = Similarity.find_similar(record_without_embedding.id)

      assert similar == []
    end

    test "filters by collection scope", %{record1: record1, record2: record2} do
      # Mark record2 as purchased
      {:ok, _} = MusicLibrary.Records.update_record(record2, %{purchased_at: DateTime.utc_now()})

      similar = Similarity.find_similar(record1.id, scope: :wishlist, max_distance: 1.0)

      # Should not include record2 since it's in collection
      record_ids = Enum.map(similar, fn %{record: record} -> record.id end)
      refute record2.id in record_ids
    end

    test "filters results by max_distance threshold", %{record1: record1} do
      # With a very low threshold, only very similar records should be returned
      similar_strict = Similarity.find_similar(record1.id, max_distance: 0.001)

      # With a very high threshold, all records should be returned
      similar_loose = Similarity.find_similar(record1.id, max_distance: 2.0)

      assert length(similar_strict) <= length(similar_loose)
    end
  end
end
