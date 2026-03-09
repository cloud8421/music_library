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

      assert {:ok, <<@pdf_magic_bytes, _::binary>>} = TracklistPdf.generate(record, release)
    end

    test "generates PDF for multi-disc release" do
      record = build_record(%{title: "Marbles", artists: [%{name: "Marillion"}]})
      api_response = MusicBrainz.Fixtures.Release.release_with_media(:marbles)
      release = Release.from_api_response(api_response)

      assert {:ok, <<@pdf_magic_bytes, _::binary>>} = TracklistPdf.generate(record, release)
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

      assert {:ok, <<@pdf_magic_bytes, _::binary>>} = TracklistPdf.generate(record, release)
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

      assert {:ok, <<@pdf_magic_bytes, _::binary>>} = TracklistPdf.generate(record, release)
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

      assert {:ok, <<@pdf_magic_bytes, _::binary>>} = TracklistPdf.generate(record, release)
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
end
