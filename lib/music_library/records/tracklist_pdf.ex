defmodule MusicLibrary.Records.TracklistPdf do
  alias MusicBrainz.Release
  alias MusicLibraryWeb.Duration
  alias Typst.Format

  @spec generate(MusicLibrary.Records.Record.t(), Release.t()) ::
          {:ok, binary()} | {:error, term()}
  def generate(record, release) do
    markup = build_markup(record, release)
    Typst.render_to_pdf(markup)
  end

  defp build_markup(record, release) do
    """
    #set page(width: 120mm, height: 120mm, margin: 5mm)
    #set text(font: "Liberation Sans", size: 8pt)

    #align(center)[
      #text(size: 10pt, weight: "bold")[#{Format.escape(artist_names(record))}]
      #linebreak()
      #text(size: 9pt, style: "italic")[#{Format.escape(record.title)}]
    ]

    #v(3mm)

    #{build_media(release)}
    """
  end

  defp build_media(release) do
    media_count = Release.media_count(release)

    release.media
    |> Enum.map_join("\n", fn medium ->
      build_medium(medium, media_count)
    end)
  end

  defp build_medium(medium, media_count) do
    header =
      if media_count > 1 do
        label = medium_label(medium)

        """
        #v(2mm)
        #text(size: 8pt, weight: "bold")[#{Format.escape(label)}]
        #v(1mm)
        """
      else
        ""
      end

    tracks =
      medium.tracks
      |> Enum.map_join("\n", &build_track/1)

    header <> tracks
  end

  defp build_track(track) do
    number = Format.escape(track.number || to_string(track.position))
    title = Format.escape(track.title)

    duration =
      if track.length do
        Format.escape(Duration.format_duration(track.length))
      else
        ""
      end

    """
    #grid(
      columns: (12pt, 1fr, auto),
      gutter: 4pt,
      align(right)[#{number}],
      [#{title}],
      align(right)[#{duration}]
    )\
    """
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
