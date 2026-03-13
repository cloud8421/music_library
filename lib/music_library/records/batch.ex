defmodule MusicLibrary.Records.Batch do
  @moduledoc """
  Batch operations for records: refresh MusicBrainz data and generate embeddings.
  """

  import Ecto.Query

  alias MusicLibrary.Batch
  alias MusicLibrary.Records
  alias MusicLibrary.Records.Record

  @spec refresh_musicbrainz_data() :: {:ok, [String.t()]}
  def refresh_musicbrainz_data do
    Batch.run_on_all(from(r in Record), "record", fn record ->
      Records.refresh_musicbrainz_data_async(record)
    end)
  end

  @spec generate_embeddings() :: {:ok, [String.t()]}
  def generate_embeddings do
    Batch.run_on_all(from(r in Record), "record", fn record ->
      Records.generate_embedding_async(record)
    end)
  end
end
