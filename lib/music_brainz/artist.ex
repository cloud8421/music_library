defmodule MusicBrainz.Artist do
  @enforce_keys [:id, :name, :sort_name]
  defstruct [:id, :name, :sort_name, :country, :relations, :musicbrainz_data]

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

  def get_discogs_id(r) do
    Enum.find_value(r.relations, fn relation ->
      if relation.type == "discogs", do: parse_discogs_id(relation.url["resource"])
    end)
  end

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

  defp parse_discogs_id("https://www.discogs.com/artist/" <> id), do: id
  defp parse_discogs_id(_other), do: nil
end
