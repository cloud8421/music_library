defmodule MusicLibrary.Records.SimilarityTest do
  use MusicLibrary.DataCase

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

  describe "cosine_similarity/2" do
    test "calculates similarity between identical vectors" do
      vec = [1.0, 2.0, 3.0, 4.0]
      similarity = Similarity.cosine_similarity(vec, vec)

      assert_in_delta similarity, 1.0, 0.0001
    end

    test "calculates similarity between orthogonal vectors" do
      vec_a = [1.0, 0.0, 0.0]
      vec_b = [0.0, 1.0, 0.0]
      similarity = Similarity.cosine_similarity(vec_a, vec_b)

      assert_in_delta similarity, 0.0, 0.0001
    end

    test "calculates similarity between opposite vectors" do
      vec_a = [1.0, 0.0, 0.0]
      vec_b = [-1.0, 0.0, 0.0]
      similarity = Similarity.cosine_similarity(vec_a, vec_b)

      assert_in_delta similarity, -1.0, 0.0001
    end

    test "calculates similarity between similar vectors" do
      vec_a = [1.0, 2.0, 3.0]
      vec_b = [1.1, 2.1, 2.9]
      similarity = Similarity.cosine_similarity(vec_a, vec_b)

      # Should be close to 1.0 since vectors are similar
      assert similarity > 0.99
    end

    test "raises error for vectors of different lengths" do
      vec_a = [1.0, 2.0, 3.0]
      vec_b = [1.0, 2.0]

      assert_raise ArgumentError, fn ->
        Similarity.cosine_similarity(vec_a, vec_b)
      end
    end

    test "handles zero vectors" do
      vec_a = [0.0, 0.0, 0.0]
      vec_b = [1.0, 2.0, 3.0]
      similarity = Similarity.cosine_similarity(vec_a, vec_b)

      assert similarity == 0.0
    end
  end

  describe "store_embedding/3 and get_embedding/1" do
    test "stores and retrieves an embedding" do
      record = record()
      embedding = Enum.map(1..1536, fn _ -> :rand.uniform() end)
      text_rep = "Test representation"

      assert {:ok, _} = Similarity.store_embedding(record.id, embedding, text_rep)
      assert {:ok, retrieved_embedding} = Similarity.get_embedding(record.id)

      assert length(retrieved_embedding) == 1536
      # Check that embeddings are the same (within floating point precision)
      Enum.zip(embedding, retrieved_embedding)
      |> Enum.each(fn {a, b} -> assert_in_delta a, b, 0.0001 end)
    end

    test "updates existing embedding on conflict" do
      record = record()
      embedding1 = Enum.map(1..1536, fn _ -> 0.5 end)
      embedding2 = Enum.map(1..1536, fn _ -> 0.7 end)

      assert {:ok, _} = Similarity.store_embedding(record.id, embedding1, "Text 1")
      assert {:ok, _} = Similarity.store_embedding(record.id, embedding2, "Text 2")

      assert {:ok, retrieved_embedding} = Similarity.get_embedding(record.id)
      assert List.first(retrieved_embedding) == 0.7
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
      similar = Similarity.find_similar(record1.id, limit: 5)

      assert length(similar) >= 1
      # record2 should be most similar to record1
      {first_record, similarity} = List.first(similar)
      assert first_record.id == record2.id
      assert similarity > 0.9
    end

    test "respects limit option", %{record1: record1} do
      similar = Similarity.find_similar(record1.id, limit: 1)

      assert length(similar) == 1
    end

    test "respects min_similarity option", %{record1: record1} do
      similar = Similarity.find_similar(record1.id, min_similarity: 0.99)

      # Since we have slight variations, only very similar records pass
      assert length(similar) <= 1
    end

    test "returns empty list for record without embedding" do
      record_without_embedding = record()

      similar = Similarity.find_similar(record_without_embedding.id)

      assert similar == []
    end

    test "filters by collection scope", %{record1: record1, record2: record2} do
      # Mark record2 as purchased
      {:ok, _} = MusicLibrary.Records.update_record(record2, %{purchased_at: DateTime.utc_now()})

      similar = Similarity.find_similar(record1.id, scope: :wishlist)

      # Should not include record2 since it's in collection
      record_ids = Enum.map(similar, fn {record, _} -> record.id end)
      refute record2.id in record_ids
    end
  end
end
