defmodule MusicLibraryWeb.ArtistLive.Biography do
  @moduledoc """
  Helper functions for building and rendering artist biographies
  from Wikipedia and Last.fm data.
  """

  alias MusicLibrary.Artists.ArtistInfo
  alias MusicLibraryWeb.Markdown
  alias Phoenix.HTML

  @spec build(ArtistInfo.t()) :: map() | nil
  def build(artist_info) do
    bio_html = ArtistInfo.wikipedia_bio(artist_info)

    if bio_html do
      %{
        source: "Wikipedia",
        summary_html: ArtistInfo.wikipedia_summary(artist_info),
        bio_html: bio_html,
        url: ArtistInfo.wikipedia_url(artist_info),
        description: ArtistInfo.wikipedia_description(artist_info)
      }
    end
  end

  # Bios start with text, then a link to read more on Last.fm, followed by a license text.
  # We split the bio at the read more link in order to render the license separately.
  @spec render_bio(String.t()) :: Phoenix.HTML.safe()
  def render_bio(bio) do
    last_fm_link_regex = ~r/<a.*Read more on Last\.fm<\/a>\.*\s*/

    case String.split(bio, last_fm_link_regex, include_captures: true) do
      [text, link, ""] ->
        reformatted_bio =
          Enum.join([
            text,
            ~s(<p class="mt-4 font-semibold text-zinc-700 hover:text-zinc-500 dark:text-zinc-300 dark:hover:text-zinc-200">#{link}</p>)
          ])

        render_content(reformatted_bio)

      [text, link, license] ->
        reformatted_bio =
          Enum.join([
            text,
            ~s(<p class="mt-4 font-semibold text-zinc-700 hover:text-zinc-500 dark:text-zinc-300 dark:hover:text-zinc-200">#{link}</p>),
            ~s(<p class="mt-4 italic block">#{license}</p>)
          ])

        render_content(reformatted_bio)

      other ->
        render_content(Enum.join(other))
    end
  end

  @spec remove_read_more_link(String.t()) :: Phoenix.HTML.safe()
  def remove_read_more_link(summary) do
    last_fm_link_regex = ~r/<a.*Read more on Last\.fm<\/a>\.*\s*/
    reformatted_summary = String.replace(summary, last_fm_link_regex, "")

    render_content(reformatted_summary)
  end

  # sobelow_skip ["XSS.Raw"]
  # Markdown.to_html/1 sanitizes HTML via MDEx (ammonia)
  defp render_content(content) do
    content
    |> Markdown.to_html()
    |> HTML.raw()
  end
end
