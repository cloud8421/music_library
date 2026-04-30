defmodule MusicLibrary.Records.Import do
  @moduledoc """
  Import records from MusicBrainz release groups and releases.

  Handles cover art fetching, barcode scan integration, and release status checks.
  """

  import Ecto.Query, warn: false
  import MusicLibrary.Records.Query

  alias MusicLibrary.Assets
  alias MusicLibrary.Records
  alias MusicLibrary.Records.{ArtistRecord, Record, SearchIndex}
  alias MusicLibrary.Repo

  @type import_opts :: [
          format: atom(),
          purchased_at: DateTime.t() | nil,
          selected_release_id: String.t() | nil
        ]

  @spec get_release_status(String.t(), atom()) ::
          :new | {:wishlisted, String.t()} | {:collected, String.t()}
  def get_release_status(release_id, format) do
    format_str = Atom.to_string(format)

    q =
      from r in fragment("records, json_each(records.release_ids)"),
        where: fragment("records.format = ?", ^format_str) and r.value == ^release_id,
        select: %{
          record_id: fragment("records.id"),
          purchased_at: fragment("records.purchased_at")
        }

    case Repo.one(q) do
      nil -> :new
      %{record_id: record_id, purchased_at: nil} -> {:wishlisted, record_id}
      %{record_id: record_id} -> {:collected, record_id}
    end
  end

  @spec get_artist_records(String.t()) :: [SearchIndex.t()]
  def get_artist_records(musicbrainz_id) do
    q =
      from r in Record,
        join: ar in ArtistRecord,
        on: r.id == ar.record_id and ar.musicbrainz_id == ^musicbrainz_id,
        select: ^essential_fields()

    Repo.all(q)
  end

  @spec import_from_musicbrainz_release(String.t(), import_opts()) ::
          {:ok, Record.t()} | {:error, term()}
  def import_from_musicbrainz_release(musicbrainz_id, opts \\ []) do
    case MusicBrainz.get_release(musicbrainz_id) do
      {:ok, release} ->
        release_group_id = release["release-group"]["id"]
        import_from_musicbrainz_release_group(release_group_id, opts)

      error ->
        error
    end
  end

  @spec import_from_musicbrainz_release_group(String.t(), import_opts()) ::
          {:ok, Record.t()} | {:error, term()}
  def import_from_musicbrainz_release_group(musicbrainz_id, opts \\ []) do
    format = Keyword.get(opts, :format, "cd")
    purchased_at = Keyword.get(opts, :purchased_at)
    selected_release_id = Keyword.get(opts, :selected_release_id, nil)

    with {:ok, release_group} <- MusicBrainz.get_release_group(musicbrainz_id),
         {:ok, releases} <- MusicBrainz.get_all_releases(musicbrainz_id),
         release_group_with_releases = Map.put(release_group, "releases", releases),
         {:ok, cover_data} <- get_cover_art_or_default(musicbrainz_id),
         {:ok, asset} <- Assets.store_image(%{content: cover_data, format: "image/jpeg"}) do
      release_group_with_releases
      |> build_record_attrs(%{
        "cover_hash" => asset.hash,
        "format" => format,
        "purchased_at" => purchased_at,
        "selected_release_id" => selected_release_id
      })
      |> Records.create_record()
    end
  end

  defp get_cover_art_or_default(musicbrainz_id) do
    case MusicBrainz.get_cover_art({:musicbrainz_id, musicbrainz_id}) do
      {:error, :cover_not_available} -> {:ok, Assets.Image.fallback_data()}
      {:ok, cover_data} -> Assets.Image.resize(cover_data)
    end
  end

  defp build_record_attrs(release_group, attrs) do
    release_group
    |> Record.attrs_from_release_group()
    |> Map.merge(attrs)
  end
end
