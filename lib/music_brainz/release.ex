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

  @type t :: %__MODULE__{
          id: String.t(),
          title: String.t(),
          disambiguation: String.t() | nil,
          packaging: String.t() | nil,
          artists: [Artist.t()],
          date: String.t() | nil,
          barcode: String.t() | nil,
          catalog_number: String.t(),
          country: String.t() | nil,
          media: [Medium.t()]
        }

  defmodule Artist do
    @enforce_keys [:id, :name, :sort_name]
    defstruct [:id, :name, :sort_name]

    @type t :: %__MODULE__{
            id: String.t(),
            name: String.t(),
            sort_name: String.t()
          }
  end

  defmodule Medium do
    @enforce_keys [:title, :format, :number, :track_count, :tracks]
    defstruct [:title, :format, :number, :track_count, :tracks]

    @type t :: %__MODULE__{
            title: String.t() | nil,
            format: String.t() | nil,
            number: non_neg_integer(),
            track_count: non_neg_integer(),
            tracks: [MusicBrainz.Release.Track.t()]
          }
  end

  defmodule Track do
    @enforce_keys [:id, :title, :artists, :length, :number, :position]
    defstruct [:id, :title, :artists, :length, :number, :position]

    @type t :: %__MODULE__{
            id: String.t(),
            title: String.t(),
            artists: [MusicBrainz.Release.Artist.t()],
            length: non_neg_integer() | nil,
            number: String.t(),
            position: non_neg_integer()
          }
  end

  @spec media_count(t()) :: non_neg_integer()
  def media_count(release) do
    Enum.count(release.media)
  end

  @spec get_medium(t(), non_neg_integer()) :: Medium.t() | nil
  def get_medium(release, medium_number) do
    Enum.find(release.media, fn m -> m.number == medium_number end)
  end

  @spec medium_duration(Medium.t()) :: non_neg_integer()
  def medium_duration(medium) do
    Enum.sum_by(medium.tracks, fn track -> track.length || 0 end)
  end

  @spec medium_tracks(t(), non_neg_integer()) :: [Track.t()]
  def medium_tracks(release, medium_number) do
    case Enum.find(release.media, fn m -> m.number == medium_number end) do
      nil -> []
      medium -> medium.tracks
    end
  end

  @spec release_duration(t()) :: non_neg_integer()
  def release_duration(release) do
    Enum.sum_by(release.media, fn medium -> medium_duration(medium) end)
  end

  @spec tracks(t()) :: [Track.t()]
  def tracks(release) do
    Enum.flat_map(release.media, fn medium -> medium.tracks end)
  end

  @spec from_api_response(map()) :: t()
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

  @spec thumb_url(t()) :: String.t()
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
