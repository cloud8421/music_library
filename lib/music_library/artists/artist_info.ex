defmodule MusicLibrary.Artists.ArtistInfo do
  use Ecto.Schema

  import Ecto.Changeset

  alias MusicBrainz.ExternalLink
  alias MusicLibrary.Notes.Note

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "artist_infos" do
    field :musicbrainz_data, :map, default: %{}
    field :discogs_data, :map, default: %{}
    field :wikipedia_data, :map, default: %{}
    field :lastfm_data, :map, default: %{}
    field :image_data_hash, :string

    has_one :note, Note, foreign_key: :musicbrainz_id

    timestamps(type: :utc_datetime)
  end

  @type t :: %__MODULE__{}

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(artist_info, attrs) do
    artist_info
    |> cast(attrs, [
      :id,
      :musicbrainz_data,
      :discogs_data,
      :wikipedia_data,
      :lastfm_data,
      :image_data_hash
    ])
    |> validate_required([:musicbrainz_data])
  end

  @spec country(t()) :: %{name: String.t(), code: String.t()}
  def country(artist_info) do
    area = Map.get(artist_info.musicbrainz_data, "area", %{})

    country_code =
      case area["iso-3166-1-codes"] || area["iso-3166-2-codes"] do
        [code | _rest] -> code
        nil -> artist_info.musicbrainz_data["country"]
      end

    %{name: area["name"] || "World", code: country_code || "XW"}
  end

  @spec extract_image(t()) ::
          {:ok, %{url: String.t(), width: integer()}}
          | {:error, :no_discogs_data | :image_not_found}
  def extract_image(artist_info) when is_nil(artist_info.discogs_data) do
    {:error, :no_discogs_data}
  end

  def extract_image(artist_info) do
    image =
      extract_image(artist_info.discogs_data, "primary") ||
        extract_image(artist_info.discogs_data, "secondary")

    if image do
      {:ok, %{url: image["resource_url"], width: image["width"]}}
    else
      {:error, :image_not_found}
    end
  end

  defp extract_image(discogs_data, type) do
    Enum.find(discogs_data["images"] || [], fn image ->
      image["type"] == type
    end)
  end

  @external_link_patterns %{
    "ProgArchives" => "progarchives.com"
  }

  @spec external_links(t()) :: [map()]
  def external_links(artist_info),
    do: ExternalLink.external_links(artist_info.musicbrainz_data, @external_link_patterns)

  @spec discogs_id(t()) :: integer() | nil
  def discogs_id(artist_info) do
    case artist_info.discogs_data do
      %{"id" => discogs_id} -> discogs_id
      _ -> nil
    end
  end

  @spec wikidata_id(t()) :: String.t() | nil
  def wikidata_id(artist_info) do
    relations = get_in(artist_info.musicbrainz_data, ["relations"]) || []

    Enum.find_value(relations, fn
      %{"type" => "wikidata", "url" => %{"resource" => "https://www.wikidata.org/wiki/" <> id}} ->
        id

      _ ->
        nil
    end)
  end

  @spec wikipedia_bio(t()) :: String.t() | nil
  def wikipedia_bio(artist_info) do
    get_in(artist_info.wikipedia_data, ["intro_html"]) ||
      get_in(artist_info.wikipedia_data, ["extract_html"])
  end

  @spec wikipedia_summary(t()) :: String.t() | nil
  def wikipedia_summary(artist_info) do
    get_in(artist_info.wikipedia_data, ["extract"])
  end

  @spec wikipedia_url(t()) :: String.t() | nil
  def wikipedia_url(artist_info) do
    get_in(artist_info.wikipedia_data, ["content_urls", "desktop", "page"])
  end

  @spec wikipedia_description(t()) :: String.t() | nil
  def wikipedia_description(artist_info) do
    get_in(artist_info.wikipedia_data, ["description"])
  end

  @spec lastfm_tags(t()) :: [map()]
  def lastfm_tags(artist_info) do
    get_in(artist_info.lastfm_data, ["tags"]) || []
  end

  @spec lastfm_similar_artists(t()) :: [map()]
  def lastfm_similar_artists(artist_info) do
    get_in(artist_info.lastfm_data, ["similar_artists"]) || []
  end
end
