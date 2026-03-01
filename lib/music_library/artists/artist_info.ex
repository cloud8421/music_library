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

  def country(artist_info) do
    %{"area" => area} =
      artist_info.musicbrainz_data

    country_code =
      case area["iso-3166-1-codes"] || area["iso-3166-2-codes"] do
        [code | _rest] -> code
        nil -> artist_info.musicbrainz_data["country"]
      end

    %{name: area["name"] || "World", code: country_code || "XW"}
  end

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

  def external_links(artist_info),
    do: ExternalLink.external_links(artist_info.musicbrainz_data, @external_link_patterns)

  def discogs_id(artist_info) do
    case artist_info.discogs_data do
      %{"id" => discogs_id} -> discogs_id
      _ -> nil
    end
  end

  def wikidata_id(artist_info) do
    relations = get_in(artist_info.musicbrainz_data, ["relations"]) || []

    Enum.find_value(relations, fn
      %{"type" => "wikidata", "url" => %{"resource" => "https://www.wikidata.org/wiki/" <> id}} ->
        id

      _ ->
        nil
    end)
  end

  def wikipedia_bio(artist_info) do
    get_in(artist_info.wikipedia_data, ["intro_html"]) ||
      get_in(artist_info.wikipedia_data, ["extract_html"])
  end

  def wikipedia_summary(artist_info) do
    get_in(artist_info.wikipedia_data, ["extract"])
  end

  def wikipedia_url(artist_info) do
    get_in(artist_info.wikipedia_data, ["content_urls", "desktop", "page"])
  end

  def wikipedia_description(artist_info) do
    get_in(artist_info.wikipedia_data, ["description"])
  end

  def lastfm_tags(artist_info) do
    get_in(artist_info.lastfm_data, ["tags"]) || []
  end

  def lastfm_similar_artists(artist_info) do
    get_in(artist_info.lastfm_data, ["similar_artists"]) || []
  end
end
