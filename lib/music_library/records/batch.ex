defmodule MusicLibrary.Records.Batch do
  import Ecto.Query

  alias MusicLibrary.Batch
  alias MusicLibrary.Records
  alias MusicLibrary.Records.Record

  def refresh_musicbrainz_data do
    Batch.run_on_all(from(r in Record), "record", fn record ->
      Records.refresh_musicbrainz_data_async(record)
    end)
  end

  def generate_embeddings do
    Batch.run_on_all(from(r in Record), "record", fn record ->
      Records.generate_embedding_async(record)
    end)
  end
end
