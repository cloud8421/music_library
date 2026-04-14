defmodule MusicLibrary.Records.Record do
  use Ecto.Schema

  import Ecto.Changeset

  alias MusicBrainz.{Release, ReleaseGroup}
  alias MusicLibrary.{Artists.Artist, Notes.Note}

  @formats [:cd, :backup, :vinyl, :blu_ray, :dvd, :multi]
  @types [:album, :ep, :live, :compilation, :single, :other]

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "records" do
    field :type, Ecto.Enum, values: @types
    field :format, Ecto.Enum, values: @formats
    field :title, :string
    field :cover_url, :string
    field :cover_hash, :string
    field :musicbrainz_id, Ecto.UUID
    field :musicbrainz_data, :map, default: %{}
    field :genres, {:array, :string}
    field :release_date, :string
    field :purchased_at, :utc_datetime
    field :selected_release_id, :string
    field :release_ids, {:array, :string}, default: []
    field :included_release_group_ids, {:array, :string}, default: []
    field :dominant_colors, {:array, :string}, default: []

    embeds_many :artists, Artist, on_replace: :delete
    has_one :note, Note, foreign_key: :musicbrainz_id, references: :musicbrainz_id

    timestamps(type: :utc_datetime)
  end

  @type t :: %__MODULE__{}

  @spec artist_names(t()) :: String.t()
  def artist_names(record) do
    record.artists
    |> Enum.map_join(fn artist -> artist.name <> artist.joinphrase end)
    |> String.trim()
  end

  @spec main_artist(t()) :: Artist.t() | nil
  def main_artist(record) do
    case record.artists do
      [] -> nil
      [main_artist | _] -> main_artist
    end
  end

  @spec artist_ids(t()) :: [String.t()]
  def artist_ids(record) do
    Enum.map(record.artists, fn artist -> artist.musicbrainz_id end)
  end

  @spec formats() :: [atom()]
  def formats, do: @formats

  @spec types() :: [atom()]
  def types, do: @types

  @spec included_release_groups(t()) :: [map()]
  def included_release_groups(record) do
    record.musicbrainz_data
    |> ReleaseGroup.included_release_groups()
    |> Enum.filter(fn rg -> rg.id in record.included_release_group_ids end)
  end

  @spec included_release_groups_count(t()) :: non_neg_integer()
  def included_release_groups_count(record) do
    Enum.count(record.included_release_group_ids)
  end

  @spec release_count(t()) :: non_neg_integer()
  def release_count(record) do
    Enum.count(record.release_ids)
  end

  @spec released?(t(), Date.t()) :: boolean()
  def released?(%{release_date: nil}, _current_day), do: true

  def released?(record, current_day) do
    case Date.from_iso8601(record.release_date) do
      {:ok, release_date} ->
        Date.compare(current_day, release_date) != :lt

      _error ->
        # When a release date cannot be parsed it's normally because the record
        # is old and information is not specific, so we can err on the side of assuming
        # it's been released.
        true
    end
  end

  @spec released_how_long_ago?(t(), Date.t()) :: non_neg_integer() | nil
  def released_how_long_ago?(%{release_date: nil}, _current_day), do: nil

  def released_how_long_ago?(record, current_day) do
    case Date.from_iso8601(record.release_date) do
      {:ok, release_date} ->
        # approximate calculation of "how many years ago",
        # we don't really care about leap years
        diff_days = Date.diff(current_day, release_date)
        div(diff_days, 365)

      _error ->
        nil
    end
  end

  @spec releases(t()) :: [MusicBrainz.Release.t()]
  def releases(record) do
    record.musicbrainz_data
    |> ReleaseGroup.releases()
    |> Enum.map(&Release.from_api_response/1)
    |> Enum.sort_by(fn r -> {r.date, r.country} end, :desc)
  end

  @spec selected_release(t()) :: MusicBrainz.Release.t() | nil
  def selected_release(record) do
    find_release(record, record.selected_release_id)
  end

  @spec find_release(t(), String.t() | nil) :: MusicBrainz.Release.t() | nil
  def find_release(record, release_id) do
    record
    |> releases()
    |> Enum.find(fn release -> release.id == release_id end)
  end

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(record, attrs) do
    record
    |> cast(attrs, [
      :type,
      :format,
      :title,
      :musicbrainz_id,
      :musicbrainz_data,
      :release_date,
      :genres,
      :release_ids,
      :selected_release_id,
      :included_release_group_ids,
      :cover_url,
      :cover_hash,
      :dominant_colors,
      :purchased_at
    ])
    |> cast_embed(:artists)
    |> validate_required([:type, :title, :musicbrainz_id, :genres])
    |> unique_constraint(:musicbrainz_id, name: "records_musicbrainz_id_format_index")
    |> update_release_ids()
    |> update_included_release_group_ids()
  end

  @spec add_genres(t(), [String.t()]) :: Ecto.Changeset.t()
  def add_genres(record, genres) do
    change(record, genres: genres)
  end

  @spec set_cover_hash(t(), String.t()) :: Ecto.Changeset.t()
  def set_cover_hash(record, cover_hash) do
    record
    |> change(cover_hash: cover_hash)
  end

  @spec add_musicbrainz_data(t(), map()) :: Ecto.Changeset.t()
  def add_musicbrainz_data(record, musicbrainz_data) do
    record
    |> change()
    |> force_change(:musicbrainz_data, musicbrainz_data)
    |> update_artists()
    |> update_release_ids()
    |> update_included_release_group_ids()
    |> update_musicbrainz_data_derived_fields()
  end

  @spec rotate_dominant_colors(t() | Ecto.Changeset.t()) :: Ecto.Changeset.t()
  def rotate_dominant_colors(%__MODULE__{dominant_colors: dominant_colors} = record) do
    change(record, dominant_colors: rotate(dominant_colors))
  end

  def rotate_dominant_colors(changeset) do
    dominant_colors = get_field(changeset, :dominant_colors)
    put_change(changeset, :dominant_colors, rotate(dominant_colors))
  end

  defp rotate([]), do: []
  defp rotate([first | rest]), do: rest ++ [first]

  defp update_release_ids(changeset) do
    case get_change(changeset, :musicbrainz_data) do
      nil ->
        changeset

      musicbrainz_data ->
        put_change(changeset, :release_ids, ReleaseGroup.release_ids(musicbrainz_data))
    end
  end

  defp update_artists(changeset) do
    case get_change(changeset, :musicbrainz_data) do
      nil ->
        changeset

      musicbrainz_data ->
        put_change(changeset, :artists, parse_artists(musicbrainz_data))
    end
  end

  defp update_included_release_group_ids(changeset) do
    case get_change(changeset, :musicbrainz_data) do
      nil ->
        changeset

      musicbrainz_data ->
        put_change(
          changeset,
          :included_release_group_ids,
          ReleaseGroup.included_release_group_ids(musicbrainz_data)
        )
    end
  end

  defp update_musicbrainz_data_derived_fields(changeset) do
    case get_change(changeset, :musicbrainz_data) do
      nil ->
        changeset

      musicbrainz_data ->
        changeset
        |> put_change(:title, musicbrainz_data["title"])
        |> put_change(:release_date, musicbrainz_data["first-release-date"])
        |> put_change(
          :cover_url,
          "https://coverartarchive.org/release-group/#{musicbrainz_data["id"]}/front"
        )
    end
  end

  @spec attrs_from_release_group(map()) :: map()
  def attrs_from_release_group(release_group) do
    musicbrainz_id = release_group["id"]

    artists_attrs = parse_artists(release_group)

    %{
      "musicbrainz_id" => musicbrainz_id,
      "musicbrainz_data" => release_group,
      "title" => release_group["title"],
      "artists" => artists_attrs,
      "release_date" => release_group["first-release-date"],
      "type" => parse_subtype(release_group["primary-type"], release_group["secondary-types"]),
      "genres" => Enum.map(release_group["genres"], fn g -> g["name"] end),
      "release_ids" => Enum.map(release_group["releases"], fn r -> r["id"] end),
      "cover_url" => "https://coverartarchive.org/release-group/#{musicbrainz_id}/front"
    }
  end

  defp parse_artists(musicbrainz_data) do
    musicbrainz_data
    |> get_in(["artist-credit", Access.all()])
    |> Enum.map(fn artist_credit ->
      %{
        name: artist_credit["artist"]["name"],
        musicbrainz_id: artist_credit["artist"]["id"],
        sort_name: artist_credit["artist"]["sort-name"],
        disambiguation: artist_credit["artist"]["disambiguation"],
        joinphrase: artist_credit["joinphrase"]
      }
    end)
  end

  defp parse_subtype("Album", secondary_types), do: parse_secondary_types(secondary_types)
  defp parse_subtype("EP", _secondary_types), do: :ep
  defp parse_subtype("Single", _secondary_types), do: :single
  defp parse_subtype(_primary_type, _secondary_types), do: :other

  defp parse_secondary_types(secondary_types) do
    cond do
      "Live" in secondary_types -> :live
      "Compilation" in secondary_types -> :compilation
      true -> :album
    end
  end

  @doc """
  Format a release date in a conventional format.

  Release dates as returned by MusicBrainz have different levels of precision,
  and can be nil or empty string.

      iex> alias MusicLibrary.Records.Record
      iex> Record.format_release_date(nil)
      "N/A"
      iex> Record.format_release_date("")
      "N/A"
      iex> Record.format_release_date("2021")
      "2021"
      iex> Record.format_release_date("2021-12")
      "12/2021"
      iex> Record.format_release_date("2021-12-23")
      "23/12/2021"
  """
  @spec format_release_date(String.t() | nil) :: String.t()
  def format_release_date(nil), do: "N/A"

  def format_release_date(release_date) do
    case String.split(release_date, "-", trim: true) do
      [] -> "N/A"
      [year] -> year
      [year, month] -> "#{month}/#{year}"
      [year, month, day] -> "#{day}/#{month}/#{year}"
    end
  end

  @spec format_as_date(DateTime.t() | NaiveDateTime.t() | Date.t()) :: String.t()
  def format_as_date(dt) do
    Calendar.strftime(dt, "%d/%m/%Y")
  end

  @spec parse_matching_record(map()) :: map() | no_return()
  def parse_matching_record(%{
        "id" => id,
        "title" => title,
        "format" => format,
        "type" => type,
        "purchased_at" => purchased_at,
        "cover_hash" => cover_hash
      }) do
    %{
      id: id,
      title: title,
      format: parse_format(format),
      type: parse_type(type),
      purchased_at: parse_datetime(purchased_at),
      cover_hash: cover_hash
    }
  end

  for type <- @types do
    defp parse_type(unquote(Atom.to_string(type))), do: unquote(type)
  end

  for format <- @formats do
    defp parse_format(unquote(Atom.to_string(format))), do: unquote(format)
  end

  defp parse_datetime(nil), do: nil

  defp parse_datetime(dt_string) do
    {:ok, dt, _offset} = DateTime.from_iso8601(dt_string)
    dt
  end
end
