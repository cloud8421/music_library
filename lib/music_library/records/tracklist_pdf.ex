defmodule MusicLibrary.Records.TracklistPdf do
  alias MusicBrainz.Release
  alias MusicLibraryWeb.Duration
  alias Typst.Format

  @layout_configs [
    {1, 8, true},
    {2, 8, true},
    {2, 7, true},
    {3, 7, true},
    {3, 6, true},
    {4, 6, false},
    {4, 5, false}
  ]

  # Empirically measured per-column capacities at block(spacing: 2pt),
  # including the header area consumed by artist name and album title.
  @capacities %{8 => 35, 7 => 38, 6 => 45, 5 => 53}

  @spec generate(MusicLibrary.Records.Record.t(), Release.t()) ::
          {:ok, binary()} | {:error, term()}
  def generate(record, release) do
    markup = build_markup(record, release.media)
    Typst.render_to_pdf(markup)
  end

  @spec generate_medium(MusicLibrary.Records.Record.t(), Release.t(), integer()) ::
          {:ok, binary()} | {:error, term()}
  def generate_medium(record, release, medium_number) do
    case Release.get_medium(release, medium_number) do
      nil -> {:error, :medium_not_found}
      medium -> generate(record, %{release | media: [medium]})
    end
  end

  defp build_markup(record, media) do
    media_count = length(media)
    track_count = Enum.sum(Enum.map(media, &length(&1.tracks)))
    header_count = if media_count > 1, do: media_count, else: 0
    total_items = track_count + header_count

    {columns, font_size, show_duration} = layout_params(total_items, media_count)

    content = build_media(media, media_count, font_size, show_duration)

    """
    #set page(width: 120mm, height: 120mm, margin: 5mm, columns: #{columns}, background: rect(width: 100%, height: 100%, stroke: 0.5pt + black))
    #set text(font: "Liberation Sans", size: #{font_size}pt)
    #set block(spacing: 2pt)

    #place(top + center, scope: "parent", float: true)[
      #align(center)[
        #text(size: 10pt, weight: "bold")[#{Format.escape(artist_names(record))}]
        #linebreak()
        #text(size: 9pt, style: "italic")[#{Format.escape(record.title)}]
      ]
      #v(3mm)
    ]

    #{content}
    """
  end

  defp build_media(media, media_count, font_size, show_duration) do
    media
    |> Enum.map_join("\n", fn medium ->
      build_medium(medium, media_count, font_size, show_duration)
    end)
  end

  defp build_medium(medium, media_count, font_size, show_duration) do
    header =
      if media_count > 1 do
        label = medium_label(medium)

        """
        #v(1.5mm)
        #text(weight: "bold")[#{Format.escape(label)}]
        #v(0.5mm)
        """
      else
        ""
      end

    tracks =
      medium.tracks
      |> Enum.map_join("\n", &build_track(&1, font_size, show_duration))

    header <> tracks
  end

  defp build_track(track, font_size, show_duration) do
    number = Format.escape(track.number || to_string(track.position))
    title = Format.escape(track.title)
    number_width = font_size + 2

    if show_duration do
      duration =
        if track.length do
          Format.escape(Duration.format_duration(track.length))
        else
          ""
        end

      """
      #grid(
        columns: (#{number_width}pt, 1fr, auto),
        gutter: 2pt,
        align(right)[#{number}],
        [#{title}],
        align(right)[#{duration}]
      )\
      """
    else
      """
      #grid(
        columns: (#{number_width}pt, 1fr),
        gutter: 2pt,
        align(right)[#{number}],
        [#{title}]
      )\
      """
    end
  end

  @doc false
  def layout_params(total_items, _media_count) do
    Enum.find(@layout_configs, List.last(@layout_configs), fn {columns, font_size, _} ->
      capacity(columns, font_size) >= total_items
    end)
  end

  defp capacity(columns, font_size) do
    Map.fetch!(@capacities, font_size) * columns
  end

  defp artist_names(record) do
    Enum.map_join(record.artists, fn artist ->
      artist.name <> (artist.joinphrase || "")
    end)
  end

  defp medium_label(medium) do
    title =
      if medium.title && medium.title != "" do
        medium.title
      else
        "Disc #{medium.number}"
      end

    if medium.format do
      "#{title} (#{medium.format})"
    else
      title
    end
  end
end
