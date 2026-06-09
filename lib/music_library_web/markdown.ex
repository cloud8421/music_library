defmodule MusicLibraryWeb.Markdown do
  @moduledoc """
  Custom markdown processor that handles double square bracket links
  and streaming markdown rendering for chat.

  Text wrapped in double square brackets like `[[Foo]]` will be rendered as
  search links to the collection page.
  """
  alias MusicLibrary.Records

  @mdex_options [
    extension: [autolink: true, strikethrough: true, table: true],
    render: [unsafe: true],
    sanitize: MDEx.Document.default_sanitize_options(),
    syntax_highlight: [engine: :lumis]
  ]

  @link_target_sanitize_options Keyword.put(
                                  MDEx.Document.default_sanitize_options(),
                                  :add_tag_attributes,
                                  %{"a" => ["target"]}
                                )

  @link_target_mdex_options Keyword.put(@mdex_options, :sanitize, @link_target_sanitize_options)

  @doc """
  Converts markdown with custom `[[link]]` syntax to HTML.

  Double square brackets are converted to search links before the markdown is processed.
  """
  @spec to_html(String.t() | nil, keyword()) :: String.t()
  def to_html(markdown_text, opts \\ [])

  def to_html(markdown_text, opts) when is_binary(markdown_text) do
    :telemetry.span(
      [:markdown, :to_html],
      %{},
      fn ->
        processed = process_double_bracket_links(markdown_text)

        result =
          if opts[:link_target] do
            processed
            |> MDEx.parse_document!(@link_target_mdex_options)
            |> open_links_in_new_tab(opts[:link_target])
            |> MDEx.to_html!()
          else
            MDEx.to_html!(processed, @mdex_options)
          end

        {result, %{}}
      end
    )
  end

  def to_html(nil, _opts), do: ""

  @doc """
  Creates a new streaming MDEx document for incremental markdown rendering.
  """
  @spec new_streaming_doc(keyword()) :: MDEx.Document.t()
  def new_streaming_doc(opts \\ []) do
    mdex_options = if opts[:link_target], do: @link_target_mdex_options, else: @mdex_options
    MDEx.new([streaming: true] ++ mdex_options)
  end

  @doc """
  Renders a streaming MDEx document to HTML.
  """
  @spec streaming_to_html(MDEx.Document.t(), keyword()) :: String.t()
  def streaming_to_html(doc, opts \\ [])

  def streaming_to_html(%MDEx.Document{} = doc, opts) do
    :telemetry.span(
      [:markdown, :streaming_to_html],
      %{},
      fn ->
        doc = if opts[:link_target], do: open_links_in_new_tab(doc, opts[:link_target]), else: doc
        result = MDEx.to_html!(doc)
        {result, %{}}
      end
    )
  end

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

  defp open_links_in_new_tab(doc, target) do
    MDEx.Document.update_nodes(doc, MDEx.Link, fn %MDEx.Link{url: url} = link ->
      if external_link?(url) do
        text = extract_text(link.nodes)

        title_attr =
          if link.title != "" and link.title != nil,
            do: ~s( title="#{html_escape(link.title)}"),
            else: ""

        %MDEx.HtmlInline{
          literal:
            ~s(<a href="#{html_escape(url)}" target="#{target}"#{title_attr}>#{html_escape(text)}</a>)
        }
      else
        link
      end
    end)
  end

  defp external_link?(url), do: url =~ ~r"^https?://"

  defp extract_text(nodes) when is_list(nodes), do: Enum.map_join(nodes, "", &extract_text/1)
  defp extract_text(%{literal: literal}), do: literal
  defp extract_text(%{nodes: nodes}), do: extract_text(nodes)
  defp extract_text(_), do: ""

  defp html_escape(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
  end
end
