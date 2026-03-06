defmodule MusicLibraryWeb.Markdown do
  @moduledoc """
  Custom markdown processor that handles double square bracket links.

  Text wrapped in double square brackets like `[[Foo]]` will be rendered as 
  search links to the collection page.
  """
  alias MusicLibrary.Records

  @doc """
  Converts markdown with custom `[[link]]` syntax to HTML.

  Double square brackets are converted to search links before the markdown is processed.
  """
  @spec to_html(String.t() | nil) :: String.t()
  def to_html(markdown_text) when is_binary(markdown_text) do
    :telemetry.span(
      [:markdown, :to_html],
      %{},
      fn ->
        result =
          markdown_text
          |> process_double_bracket_links()
          |> Earmark.as_html!(%Earmark.Options{gfm: true})

        {result, %{}}
      end
    )
  end

  def to_html(nil), do: ""

  @doc """
  Processes text to convert [[text]] patterns into markdown links.

  Supports prefixed queries like `[[artist:Blackfield]]` where the link text
  shows only the value (e.g. "Blackfield") but the search query uses the full
  prefixed content.

  ## Examples

      iex> MusicLibraryWeb.Markdown.process_double_bracket_links("Check out [[Porcupine Tree]]")
      "Check out [Porcupine Tree](/collection?query=Porcupine+Tree)"

      iex> MusicLibraryWeb.Markdown.process_double_bracket_links("Albums like [[Steven Wilson - The Raven That Refused to Sing (and Other Stories) (2013)]] are great")
      "Albums like [Steven Wilson - The Raven That Refused to Sing (and Other Stories) (2013)](/collection?query=Steven+Wilson+-+The+Raven+That+Refused+to+Sing+%28and+Other+Stories%29+%282013%29) are great"

      iex> MusicLibraryWeb.Markdown.process_double_bracket_links("Listen to [[artist:Blackfield]]")
      "Listen to [Blackfield](/collection?query=artist%3ABlackfield)"

      iex> MusicLibraryWeb.Markdown.process_double_bracket_links(~s|[[genre:"psychedelic rock"]]|)
      ~s|[psychedelic rock](/collection?query=genre%3A%22psychedelic+rock%22)|
  """
  @spec process_double_bracket_links(String.t()) :: String.t()
  def process_double_bracket_links(text) do
    ~r/\[\[([^\]]+)\]\]/
    |> Regex.replace(text, fn _match, content ->
      encoded_content = URI.encode_www_form(content)
      "[#{display_text(content)}](/collection?query=#{encoded_content})"
    end)
  end

  defp display_text(content) do
    case Records.SearchParser.parse(content) do
      {:ok, %{query: _}} -> content
      {:ok, parsed} when map_size(parsed) == 1 -> parsed |> Map.values() |> hd() |> to_string()
      _ -> content
    end
  end
end
