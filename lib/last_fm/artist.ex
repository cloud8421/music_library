defmodule LastFm.Artist do
  @enforce_keys [:musicbrainz_id, :name]
  defstruct [:musicbrainz_id, :name, :bio, :image, :play_count]

  @type t :: %__MODULE__{
          musicbrainz_id: String.t(),
          name: String.t(),
          bio: String.t(),
          image: String.t(),
          play_count: non_neg_integer()
        }

  def from_api_response(api_response) do
    %__MODULE__{
      musicbrainz_id: api_response["mbid"],
      name: api_response["name"],
      bio: api_response["bio"]["content"] || "",
      image: get_image(api_response),
      play_count: get_play_count(api_response)
    }
  end

  defp get_image(api_response) do
    api_response["image"]
    |> Enum.find(%{"#text" => nil}, fn i -> i["size"] == "medium" end)
    |> Map.get("#text")
  end

  defp get_play_count(api_response) do
    if play_count = get_in(api_response, ["stats", "userplaycount"]) do
      String.to_integer(play_count)
    else
      0
    end
  end
end
