defmodule Wikipedia do
  @moduledoc """
  Wikipedia API facade for artist biographies.
  """

  alias Wikipedia.API

  @spec get_artist_summary(String.t()) :: {:ok, map()} | {:error, :no_english_wikipedia | term()}
  def get_artist_summary(wikidata_id) do
    wikipedia_config = wikipedia_config()

    with {:ok, title} when not is_nil(title) <-
           API.get_wikipedia_title(wikidata_id, wikipedia_config),
         {:ok, summary} <- API.get_article_summary(title, wikipedia_config),
         {:ok, intro_html} <- API.get_article_extract(title, wikipedia_config) do
      {:ok, Map.put(summary, "intro_html", intro_html)}
    else
      {:ok, nil} -> {:error, :no_english_wikipedia}
      error -> error
    end
  end

  defp wikipedia_config, do: Wikipedia.Config.resolve(:music_library)
end
