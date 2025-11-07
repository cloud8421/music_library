defmodule MusicLibrary.Artists.ArtistInfo do
  use Ecto.Schema

  import Ecto.Changeset

  alias MusicBrainz.ExternalLink

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "artist_infos" do
    field :musicbrainz_data, :map, default: %{}
    field :discogs_data, :map, default: %{}
    field :image_data_hash, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(artist_info, attrs) do
    artist_info
    |> cast(attrs, [
      :id,
      :musicbrainz_data,
      :discogs_data,
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

    %{name: area["name"] || "World", code: keep_alpha_2(country_code) || "XW"}
  end

  defp keep_alpha_2(nil), do: nil

  defp keep_alpha_2(country_code) do
    String.slice(country_code, 0..1)
  end

  def extract_image(artist_info) when is_nil(artist_info.discogs_data) do
    {:error, :no_discogs_data}
  end

  def extract_image(artist_info) do
    primary_image = extract_image(artist_info.discogs_data, "primary")
    secondary_image = extract_image(artist_info.discogs_data, "secondary")

    if image = primary_image || secondary_image do
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
end
