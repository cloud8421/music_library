defmodule MusicLibrary.Records.TracklistPdfTest do
  use ExUnit.Case, async: true

  alias MusicBrainz.Release
  alias MusicLibrary.Records.{Record, TracklistPdf}

  @pdf_magic_bytes <<37, 80, 68, 70>>

  describe "generate/2" do
    test "generates PDF for single-disc release" do
      record = build_record(%{title: "OK Computer", artists: [%{name: "Radiohead"}]})

      release =
        build_release([
          build_medium(1, [
            build_track(1, "Airbag", 284_533),
            build_track(2, "Paranoid Android", 383_000)
          ])
        ])

      assert {:ok, <<@pdf_magic_bytes, _::binary>> = pdf} = TracklistPdf.generate(record, release)
      assert pdf_page_count(pdf) == 1
    end

    test "generates PDF for multi-disc release" do
      record = build_record(%{title: "Marbles", artists: [%{name: "Marillion"}]})
      api_response = MusicBrainz.Fixtures.Release.release_with_media(:marbles)
      release = Release.from_api_response(api_response)

      assert {:ok, <<@pdf_magic_bytes, _::binary>> = pdf} = TracklistPdf.generate(record, release)
      assert pdf_page_count(pdf) == 1
    end

    test "renders artist joinphrase correctly" do
      record =
        build_record(%{
          title: "Collab Album",
          artists: [
            %{name: "Artist A", joinphrase: " & "},
            %{name: "Artist B"}
          ]
        })

      release =
        build_release([
          build_medium(1, [build_track(1, "Track One", 200_000)])
        ])

      assert {:ok, <<@pdf_magic_bytes, _::binary>> = pdf} = TracklistPdf.generate(record, release)
      assert pdf_page_count(pdf) == 1
    end

    test "handles track without duration" do
      record = build_record(%{title: "Test Album", artists: [%{name: "Test Artist"}]})

      release =
        build_release([
          build_medium(1, [
            build_track(1, "Has Duration", 180_000),
            build_track(2, "No Duration", nil)
          ])
        ])

      assert {:ok, <<@pdf_magic_bytes, _::binary>> = pdf} = TracklistPdf.generate(record, release)
      assert pdf_page_count(pdf) == 1
    end

    test "handles special characters in title" do
      record =
        build_record(%{
          title: "Album *with* #special @chars",
          artists: [%{name: "Artist #1"}]
        })

      release =
        build_release([
          build_medium(1, [
            build_track(1, "Track *starring* @someone", 200_000),
            build_track(2, "#Hashtag Title", 180_000)
          ])
        ])

      assert {:ok, <<@pdf_magic_bytes, _::binary>> = pdf} = TracklistPdf.generate(record, release)
      assert pdf_page_count(pdf) == 1
    end
  end

  describe "generate_medium/3" do
    test "generates PDF for a single medium from a multi-disc release" do
      record = build_record(%{title: "Marbles", artists: [%{name: "Marillion"}]})
      api_response = MusicBrainz.Fixtures.Release.release_with_media(:marbles)
      release = Release.from_api_response(api_response)

      assert {:ok, <<@pdf_magic_bytes, _::binary>> = pdf} =
               TracklistPdf.generate_medium(record, release, 1)

      assert pdf_page_count(pdf) == 1
    end

    test "returns error for non-existent medium number" do
      record = build_record(%{title: "Test Album", artists: [%{name: "Test Artist"}]})

      release =
        build_release([
          build_medium(1, [build_track(1, "Track One", 200_000)])
        ])

      assert {:error, :medium_not_found} = TracklistPdf.generate_medium(record, release, 99)
    end
  end

  describe "layout_params/2" do
    test "single column for small track count" do
      assert {1, 8, true} = TracklistPdf.layout_params(10, 1)
    end

    test "two columns for medium track count" do
      assert {2, 8, true} = TracklistPdf.layout_params(40, 1)
    end

    test "scales up columns and reduces font for large track counts" do
      assert {2, 7, true} = TracklistPdf.layout_params(75, 1)
      assert {3, 7, true} = TracklistPdf.layout_params(80, 1)
      assert {3, 6, true} = TracklistPdf.layout_params(120, 1)
      assert {4, 6, false} = TracklistPdf.layout_params(150, 1)
      assert {4, 5, false} = TracklistPdf.layout_params(200, 1)
    end

    test "accounts for medium headers in multi-medium releases" do
      # 34 tracks + 2 medium headers = 36 items, exceeds single column capacity (35)
      assert {2, 8, true} = TracklistPdf.layout_params(36, 2)
    end
  end

  describe "generate/2 with many tracks" do
    test "generates single-page PDF for large single-disc release" do
      record = build_record(%{title: "Long Album", artists: [%{name: "Prolific Artist"}]})
      tracks = Enum.map(1..40, &build_track(&1, "Track #{&1}", 180_000))

      release = build_release([build_medium(1, tracks)])

      assert {:ok, <<@pdf_magic_bytes, _::binary>> = pdf} = TracklistPdf.generate(record, release)
      assert pdf_page_count(pdf) == 1
    end

    test "generates single-page PDF for large multi-disc release" do
      record = build_record(%{title: "Box Set", artists: [%{name: "Band"}]})

      media =
        Enum.map(1..4, fn disc ->
          tracks = Enum.map(1..20, &build_track(&1, "Disc #{disc} Track #{&1}", 200_000))
          build_medium(disc, tracks)
        end)

      release = build_release(media)

      assert {:ok, <<@pdf_magic_bytes, _::binary>> = pdf} = TracklistPdf.generate(record, release)
      assert pdf_page_count(pdf) == 1
    end
  end

  defp build_record(attrs) do
    artists =
      Enum.map(Map.get(attrs, :artists, []), fn a ->
        %{
          name: a[:name] || a.name,
          sort_name: a[:sort_name] || a[:name] || a.name,
          musicbrainz_id: "00000000-0000-0000-0000-000000000000",
          disambiguation: "",
          joinphrase: a[:joinphrase] || ""
        }
      end)

    %Record{
      id: Ecto.UUID.generate(),
      title: attrs[:title] || "Test Album",
      artists: artists,
      genres: [],
      type: :album,
      format: :cd
    }
  end

  defp build_release(media) do
    %Release{
      id: "00000000-0000-0000-0000-000000000000",
      title: "Test Release",
      disambiguation: nil,
      packaging: nil,
      artists: [],
      date: "2024-01-01",
      barcode: nil,
      catalog_number: "",
      country: nil,
      media: media
    }
  end

  defp build_medium(number, tracks) do
    %Release.Medium{
      title: nil,
      format: "CD",
      number: number,
      track_count: length(tracks),
      tracks: tracks
    }
  end

  defp build_track(position, title, length) do
    %Release.Track{
      id: Ecto.UUID.generate(),
      title: title,
      artists: [],
      length: length,
      number: to_string(position),
      position: position
    }
  end

  defp pdf_page_count(pdf) when is_binary(pdf) do
    # Count "/Type /Page" occurrences that are NOT "/Type /Pages" in the PDF binary
    pdf
    |> String.split("/Type /Page")
    |> tl()
    |> Enum.count(fn segment -> not String.starts_with?(segment, "s") end)
  end
end
