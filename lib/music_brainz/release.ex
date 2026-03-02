defmodule MusicBrainz.Release do
  @enforce_keys [
    :id,
    :title,
    :disambiguation,
    :packaging,
    :artists,
    :date,
    :barcode,
    :catalog_number,
    :country,
    :media
  ]
  defstruct [
    :id,
    :title,
    :disambiguation,
    :packaging,
    :artists,
    :date,
    :barcode,
    :catalog_number,
    :country,
    :media
  ]

  defmodule Artist do
    @enforce_keys [:id, :name, :sort_name]
    defstruct [:id, :name, :sort_name]
  end

  defmodule Medium do
    @enforce_keys [:title, :format, :number, :track_count, :tracks]
    defstruct [:title, :format, :number, :track_count, :tracks]
  end

  defmodule Track do
    @enforce_keys [:id, :title, :artists, :length, :number, :position]
    defstruct [:id, :title, :artists, :length, :number, :position]
  end

  def media_count(release) do
    Enum.count(release.media)
  end

  def get_medium(release, medium_number) do
    Enum.find(release.media, fn m -> m.number == medium_number end)
  end

  def medium_duration(medium) do
    Enum.sum_by(medium.tracks, fn track -> track.length || 0 end)
  end

  def medium_tracks(release, medium_number) do
    case Enum.find(release.media, fn m -> m.number == medium_number end) do
      nil -> []
      medium -> medium.tracks
    end
  end

  def release_duration(release) do
    Enum.sum_by(release.media, fn medium -> medium_duration(medium) end)
  end

  def tracks(release) do
    Enum.flat_map(release.media, fn medium -> medium.tracks end)
  end

  def from_api_response(r) do
    %__MODULE__{
      id: r["id"],
      title: r["title"],
      disambiguation: r["disambiguation"],
      packaging: r["packaging"],
      artists: parse_artists(r["artist-credit"] || []),
      date: r["date"],
      barcode: r["barcode"],
      catalog_number: parse_catalog_number(r["label-info"] || []),
      country: r["country"],
      media: parse_media(r["media"] || [])
    }
  end

  def thumb_url(release) do
    "https://coverartarchive.org/release/#{release.id}/front-250"
  end

  defp parse_media(media) do
    Enum.map(media, fn m ->
      %Medium{
        title: m["title"],
        format: m["format"],
        number: m["position"],
        track_count: m["track-count"],
        tracks: parse_tracks(m["tracks"] || [])
      }
    end)
  end

  defp parse_tracks(tracks) do
    Enum.map(tracks, fn t ->
      %Track{
        id: t["id"],
        title: t["title"],
        artists: parse_artists(t["recording"]["artist-credit"]),
        length: t["length"],
        number: t["number"],
        position: t["position"]
      }
    end)
  end

  defp parse_artists(artists) do
    Enum.map(artists, fn a ->
      %Artist{
        id: a["artist"]["id"],
        name: a["artist"]["name"],
        sort_name: a["artist"]["sort-name"]
      }
    end)
  end

  defp parse_catalog_number(label_infos) do
    Enum.map_join(label_infos, ", ", fn li ->
      li["catalog-number"]
    end)
  end
end
