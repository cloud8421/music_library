defmodule Wikipedia do
  alias Wikipedia.API

  @spec get_artist_summary(String.t()) :: {:ok, map()} | {:error, :no_english_wikipedia | term()}
  def get_artist_summary(wikidata_id) do
    config = wikipedia_config()

    with {:ok, title} when not is_nil(title) <- API.get_wikipedia_title(wikidata_id, config),
         {:ok, summary} <- API.get_article_summary(title, config),
         {:ok, intro_html} <- API.get_article_extract(title, config) do
      {:ok, Map.put(summary, "intro_html", intro_html)}
    else
      {:ok, nil} -> {:error, :no_english_wikipedia}
      error -> error
    end
  end

  defp wikipedia_config, do: Wikipedia.Config.resolve(:music_library)
end
