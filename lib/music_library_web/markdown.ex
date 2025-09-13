defmodule MusicLibraryWeb.Markdown do
  @moduledoc """
  Custom markdown processor that handles double square bracket links.

  Text wrapped in double square brackets like `[[Foo]]` will be rendered as 
  search links to the collection page.
  """

  @doc """
  Converts markdown with custom `[[link]]` syntax to HTML.

  Double square brackets are converted to search links before the markdown is processed.
  """
  def to_html(markdown_text) when is_binary(markdown_text) do
    markdown_text
    |> process_double_bracket_links()
    |> Earmark.as_html!(%Earmark.Options{gfm: true})
  end

  def to_html(nil), do: ""

  @doc """
  Processes text to convert [[text]] patterns into markdown links.

  ## Examples

      iex> MusicLibraryWeb.Markdown.process_double_bracket_links("Check out [[Porcupine Tree]]")
      "Check out [Porcupine Tree](/collection?query=Porcupine+Tree)"
      
      iex> MusicLibraryWeb.Markdown.process_double_bracket_links("Albums like [[Steven Wilson - The Raven That Refused to Sing (and Other Stories) (2013)]] are great")
      "Albums like [Steven Wilson - The Raven That Refused to Sing (and Other Stories) (2013)](/collection?query=Steven+Wilson+-+The+Raven+That+Refused+to+Sing+%28and+Other+Stories%29+%282013%29) are great"
  """
  def process_double_bracket_links(text) do
    # Regex to match [[text]] patterns
    ~r/\[\[([^\]]+)\]\]/
    |> Regex.replace(text, fn _match, content ->
      # URL encode the content for the search query
      encoded_content = URI.encode_www_form(content)
      "[#{content}](/collection?query=#{encoded_content})"
    end)
  end
end
