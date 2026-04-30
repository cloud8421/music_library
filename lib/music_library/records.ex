defmodule MusicLibrary.Records do
  @moduledoc """
  Provides functions to work with records irrespective of their status
  as part of the collection or the wishlist.

  Search, import, and enrichment functions are delegated to focused sub-contexts:
  `Records.Search`, `Records.Import`, and `Records.Enrichment`.
  """

  alias MusicLibrary.Artists
  alias MusicLibrary.Records.{Enrichment, Record}
  alias MusicLibrary.Repo

  # ---- Search delegation ----

  defdelegate search_records(initial_search, query, opts), to: MusicLibrary.Records.Search
  defdelegate search_records_count(initial_search, query), to: MusicLibrary.Records.Search
  defdelegate list_genres, to: MusicLibrary.Records.Search

  # ---- Import delegation ----

  defdelegate get_release_status(release_id, format), to: MusicLibrary.Records.Import
  defdelegate get_artist_records(musicbrainz_id), to: MusicLibrary.Records.Import

  defdelegate import_from_musicbrainz_release(musicbrainz_id, opts \\ []),
    to: MusicLibrary.Records.Import

  defdelegate import_from_musicbrainz_release_group(musicbrainz_id, opts \\ []),
    to: MusicLibrary.Records.Import

  # ---- Enrichment delegation ----

  defdelegate populate_genres(record), to: MusicLibrary.Records.Enrichment
  defdelegate populate_genres_async(record), to: MusicLibrary.Records.Enrichment
  defdelegate refresh_cover(record), to: MusicLibrary.Records.Enrichment
  defdelegate refresh_cover_async(record), to: MusicLibrary.Records.Enrichment
  defdelegate extract_colors(record), to: MusicLibrary.Records.Enrichment
  defdelegate resize_cover(record), to: MusicLibrary.Records.Enrichment
  defdelegate refresh_musicbrainz_data(record), to: MusicLibrary.Records.Enrichment
  defdelegate refresh_musicbrainz_data_async(record), to: MusicLibrary.Records.Enrichment

  # ---- CRUD functions ----

  @spec get_record(String.t()) :: Record.t() | nil
  def get_record(id), do: Repo.get(Record, id)

  @spec get_record!(String.t()) :: Record.t()
  def get_record!(id), do: Repo.get!(Record, id)

  @spec create_record(map()) :: {:ok, Record.t()} | {:error, Ecto.Changeset.t()}
  def create_record(attrs \\ %{}) do
    with {:ok, record} <- do_create_record(attrs),
         record = Enrichment.best_effort_extract_colors(record),
         :ok <- refresh_artist_info_async(record) do
      {:ok, record}
    end
  end

  @spec refresh_artist_info_async(Record.t()) :: :ok
  def refresh_artist_info_async(record) do
    record
    |> Record.artist_ids()
    |> Enum.each(fn artist_id ->
      Artists.refresh_artist_info_async(artist_id)
    end)
  end

  defp do_create_record(attrs) do
    %Record{}
    |> Record.changeset(attrs)
    |> Repo.insert()
  end

  @spec update_record(Record.t(), map()) :: {:ok, Record.t()} | {:error, Ecto.Changeset.t()}
  def update_record(%Record{} = record, attrs) do
    with {:ok, updated_record} <- do_update_record(record, attrs),
         :ok <- refresh_artist_info_async(updated_record) do
      {:ok, updated_record}
    end
  end

  defp do_update_record(record, attrs) do
    record
    |> Record.changeset(attrs)
    |> Repo.update()
  end

  @spec delete_record(Record.t()) :: {:ok, Record.t()} | {:error, Ecto.Changeset.t()}
  def delete_record(%Record{} = record) do
    with {:ok, record} <- Repo.delete(record) do
      record
      |> Record.artist_ids()
      |> Enum.each(fn artist_id ->
        Artists.prune_artist_info_async(artist_id)
      end)

      {:ok, record}
    end
  end

  @spec change_record(Record.t(), map()) :: Ecto.Changeset.t()
  def change_record(%Record{} = record, attrs \\ %{}) do
    Record.changeset(record, attrs)
  end

  # ---- PubSub functions ----

  @spec subscribe(String.t()) :: :ok | {:error, term()}
  def subscribe(record_id) do
    Phoenix.PubSub.subscribe(MusicLibrary.PubSub, "records:#{record_id}")
  end

  @spec notify_update(Record.t()) :: :ok | {:error, term()}
  def notify_update(record) do
    Phoenix.PubSub.broadcast(
      MusicLibrary.PubSub,
      "records:#{record.id}",
      {:update, record}
    )
  end
end
