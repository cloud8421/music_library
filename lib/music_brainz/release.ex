defmodule MusicBrainz.Release do
  @enforce_keys [:id, :artists, :date, :barcode, :media]
  defstruct [:id, :artists, :date, :barcode, :media]

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

  def medium_duration(medium) do
    Enum.sum_by(medium.tracks, fn track -> track.length || 0 end)
  end

  def from_api_response(r) do
    %__MODULE__{
      id: r["id"],
      artists: parse_artists(r["artist-credit"]),
      date: r["date"],
      barcode: r["barcode"],
      media: parse_media(r["media"])
    }
  end

  defp parse_media(media) do
    Enum.map(media, fn m ->
      %Medium{
        title: m["title"],
        format: m["format"],
        number: m["position"],
        track_count: m["track-count"],
        tracks: parse_tracks(m["tracks"])
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
end
