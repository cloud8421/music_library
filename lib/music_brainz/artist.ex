defmodule MusicBrainz.Artist do
  @enforce_keys [:id, :name, :sort_name]
  defstruct [:id, :name, :sort_name, :country, :relations]

  def from_api_response(r) do
    %__MODULE__{
      id: r["id"],
      name: r["name"],
      sort_name: r["sort-name"],
      country: r["country"],
      relations: parse_relations(r["relations"])
    }
  end

  defp parse_relations(relations) do
    Enum.map(relations, fn relation ->
      %{
        type: relation["type"],
        url: relation["url"]
      }
    end)
  end
end
