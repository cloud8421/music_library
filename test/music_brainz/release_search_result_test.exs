defmodule MusicBrainz.ReleaseSearchResultTest do
  use ExUnit.Case, async: true

  alias MusicBrainz.ReleaseSearchResult

  @single_cd %MusicBrainz.ReleaseSearchResult{
    id: "dc393148-be34-4056-be66-b2b95905c5c1",
    title: "Equally Cursed and Blessed",
    release_group: %{
      id: "c35fc446-65cc-3645-939b-1b3782e60639",
      type: :album,
      title: "Equally Cursed and Blessed"
    },
    artists: "Catatonia",
    date: "1999-04-12",
    barcode: "639842709422",
    media: [%{format: "CD", disc_count: 5, track_count: 11}]
  }

  @double_cd %MusicBrainz.ReleaseSearchResult{
    id: "51ebc32b-d21f-4466-9297-94b6a3e0e6ba",
    title: "Rock in Rio",
    release_group: %{
      id: "ea6dac58-887a-35a8-86ff-08c56e6bf047",
      type: :album,
      title: "Rock in Rio"
    },
    artists: "Iron Maiden",
    date: "2002-03-21",
    barcode: "724353864309",
    media: [
      %{format: "CD", disc_count: 1, track_count: 10},
      %{format: "CD", disc_count: 1, track_count: 9}
    ]
  }

  @single_vinyl %MusicBrainz.ReleaseSearchResult{
    id: "3af1f610-9df1-4a48-8874-78cd64e25888",
    title: "Somewhere in Time",
    release_group: %{
      id: "a5fe4d2d-3aab-3e86-91ad-22a3fe16c4f2",
      type: :album,
      title: "Somewhere in Time"
    },
    artists: "Iron Maiden",
    date: "1986-09-29",
    barcode: "5099924059718",
    media: [%{format: "12\" Vinyl", disc_count: 0, track_count: 8}]
  }

  @multi %MusicBrainz.ReleaseSearchResult{
    id: "804e4781-bc17-496e-8abd-d61c7173391c",
    title: "Live With the Plovdiv Psychotic Symphony",
    release_group: %{
      id: "887898c3-ef40-4162-88d3-1fbc58ee2d09",
      type: :album,
      title: "Live With the Plovdiv Psychotic Symphony"
    },
    artists: "Sons of Apollo, Пловдивска филхармония",
    date: "2019-08-30",
    barcode: "190759669228",
    media: [
      %{format: "CD", disc_count: 0, track_count: 11},
      %{format: "CD", disc_count: 1, track_count: 10},
      %{format: "CD", disc_count: 0, track_count: 3},
      %{format: "DVD-Video", disc_count: 0, track_count: 22},
      %{format: "Blu-ray", disc_count: 0, track_count: 42}
    ]
  }

  describe "format/1" do
    test "it returns the format of the release" do
      assert ReleaseSearchResult.format(@single_cd) == :cd
      assert ReleaseSearchResult.format(@single_vinyl) == :vinyl
      assert ReleaseSearchResult.format(@double_cd) == :cd
      assert ReleaseSearchResult.format(@multi) == :multi
    end
  end
end
