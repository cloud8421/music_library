defmodule MusicBrainz.ExternalLink do
  @moduledoc false

  defstruct [:name, :url]

  @type t :: %__MODULE__{
          name: atom(),
          url: String.t()
        }

  @spec external_links(map(), map() | String.t() | nil) :: [t()] | [String.t()]
  def external_links(musicbrainz_data, patterns) when is_map(patterns) do
    Enum.reduce(patterns, [], fn {name, pattern}, acc ->
      case external_links(musicbrainz_data, pattern) do
        [] ->
          acc

        [url | _rest] ->
          [%__MODULE__{name: name, url: url} | acc]
      end
    end)
  end

  def external_links(musicbrainz_data, pattern) do
    case get_in(musicbrainz_data, ["relations", Access.all(), "url", "resource"]) do
      nil -> []
      urls -> filter_urls(urls, pattern)
    end
  end

  defp filter_urls(urls, nil), do: urls

  defp filter_urls(urls, pattern) do
    Enum.filter(urls, fn url -> String.contains?(url, pattern) end)
  end
end
