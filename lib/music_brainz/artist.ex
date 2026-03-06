defmodule MusicBrainz.Artist do
  @enforce_keys [:id, :name, :sort_name]
  defstruct [:id, :name, :sort_name, :country, :relations, :musicbrainz_data]

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          sort_name: String.t(),
          country: String.t() | nil,
          relations: [map()] | nil,
          musicbrainz_data: map() | nil
        }

  @spec from_api_response(map()) :: t()
  def from_api_response(r) do
    %__MODULE__{
      id: r["id"],
      name: r["name"],
      sort_name: r["sort-name"],
      country: r["country"],
      relations: parse_relations(r["relations"] || []),
      musicbrainz_data: r
    }
  end

  # MASSIVE ASSUMPTION: if there's more than one Discogs link,
  # take the one with the lowest ID, as it's likely to be the main one.
  @spec get_discogs_id(t()) :: integer() | nil
  def get_discogs_id(r) do
    candidates =
      r.relations
      |> Enum.filter(fn relation ->
        relation.type == "discogs"
      end)
      |> Enum.map(fn relation ->
        parse_discogs_id(relation.url["resource"])
      end)
      |> Enum.sort()

    case candidates do
      [] -> nil
      [id | _rest] -> id
    end
  end

  @spec get_wikidata_id(t()) :: String.t() | nil
  def get_wikidata_id(r) do
    Enum.find_value(r.relations, fn relation ->
      if relation.type == "wikidata" do
        parse_wikidata_id(relation.url["resource"])
      end
    end)
  end

  @spec url(String.t()) :: String.t()
  def url(id) do
    "https://musicbrainz.org/artist/#{id}"
  end

  defp parse_relations(relations) do
    Enum.map(relations, fn relation ->
      %{
        type: relation["type"],
        url: relation["url"]
      }
    end)
  end

  defp parse_discogs_id("https://www.discogs.com/artist/" <> id) do
    case Integer.parse(id) do
      {int, ""} -> int
      _ -> nil
    end
  end

  defp parse_discogs_id(_other), do: nil

  defp parse_wikidata_id("https://www.wikidata.org/wiki/" <> id), do: id
  defp parse_wikidata_id(_other), do: nil
end
