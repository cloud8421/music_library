defmodule MusicBrainz.Release do
  @enforce_keys [:id, :date, :barcode, :media]
  defstruct [:id, :date, :barcode, :media]

  defmodule Medium do
    @enforce_keys [:format, :number, :track_count, :tracks]
    defstruct [:format, :number, :track_count, :tracks]
  end

  defmodule Track do
    @enforce_keys [:id, :title, :length, :number, :position]
    defstruct [:id, :title, :length, :number, :position]
  end

  def media_count(release) do
    Enum.count(release.media)
  end

  def from_api_response(r) do
    %__MODULE__{
      id: r["id"],
      date: r["date"],
      barcode: r["barcode"],
      media: parse_media(r["media"])
    }
  end

  defp parse_media(media) do
    Enum.map(media, fn m ->
      %Medium{
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
        length: t["length"],
        number: t["number"],
        position: t["position"]
      }
    end)
  end
end
