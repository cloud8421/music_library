defmodule MusicLibrary.ReleaseGroupsFixtures do
  def release_group_search_results do
    [
      %{
        id: "20790e26-98e4-3ad3-a67f-b674758b942d",
        type: :album,
        title: "Marbles",
        artists: "Marillion",
        release: "2004-05-03"
      },
      %{
        id: "bf20ac32-a793-3bb4-beff-f7b9bffaca38",
        type: :album,
        title: "Marbles Live",
        artists: "Marillion",
        release: "2005-10-24"
      }
    ]
  end

  def release_group_id do
    release_group() |> Map.get("id")
  end

  def release_group do
    %{
      "artist-credit" => [
        %{
          "artist" => %{
            "disambiguation" => "British progressive rock band",
            "genres" => [
              %{
                "count" => 10,
                "disambiguation" => "",
                "id" => "ae9b8279-3959-48d8-8a88-741a7f6d4a48",
                "name" => "progressive rock"
              }
            ],
            "id" => "1932f5b6-0b7b-4050-b1df-833ca89e5f44",
            "name" => "Marillion",
            "sort-name" => "Marillion",
            "type" => "Group",
            "type-id" => "e431f5f6-b5d2-343d-8b36-72607fffb74b"
          },
          "joinphrase" => "",
          "name" => "Marillion"
        }
      ],
      "disambiguation" => "",
      "first-release-date" => "2004-05-03",
      "genres" => [
        %{
          "count" => 1,
          "disambiguation" => "",
          "id" => "ceeaa283-5d7b-4202-8d1d-e25d116b2a18",
          "name" => "alternative rock"
        },
        %{
          "count" => 1,
          "disambiguation" => "",
          "id" => "b7ef058e-6d83-4ca4-8123-9724bff4648b",
          "name" => "art rock"
        },
        %{
          "count" => 1,
          "disambiguation" => "",
          "id" => "150eb95a-7739-4fde-a5fe-b62ca576a928",
          "name" => "baroque pop"
        },
        %{
          "count" => 1,
          "disambiguation" => "",
          "id" => "797e2e85-5ffd-495c-a757-8b4079052f0e",
          "name" => "pop rock"
        },
        %{
          "count" => 2,
          "disambiguation" => "",
          "id" => "ae9b8279-3959-48d8-8a88-741a7f6d4a48",
          "name" => "progressive rock"
        },
        %{
          "count" => 1,
          "disambiguation" => "",
          "id" => "2aeb5340-c474-4677-b9a6-35ddac9b6a58",
          "name" => "psychedelic pop"
        },
        %{
          "count" => 2,
          "disambiguation" => "",
          "id" => "0e3fc579-2d24-4f20-9dae-736e1ec78798",
          "name" => "rock"
        }
      ],
      "id" => "20790e26-98e4-3ad3-a67f-b674758b942d",
      "primary-type" => "Album",
      "primary-type-id" => "f529b476-6e62-324f-b0aa-1f3e33d313fc",
      "secondary-type-ids" => [],
      "secondary-types" => [],
      "title" => "Marbles"
    }
  end

  def release_id do
    release() |> Map.get("id")
  end

  def release do
    %{
      "asin" => nil,
      "barcode" => "",
      "country" => "XE",
      "cover-art-archive" => %{
        "artwork" => false,
        "back" => false,
        "count" => 0,
        "darkened" => false,
        "front" => false
      },
      "date" => "2004-05-03",
      "disambiguation" => "non‐deluxe double CD with o‐card",
      "id" => "0e290154-5375-4f4f-a658-4a92bf02faa5",
      "packaging" => "Jewel Case",
      "packaging-id" => "ec27701a-4a22-37f4-bfac-6616e0f9750a",
      "quality" => "normal",
      "release-events" => [
        %{
          "area" => %{
            "disambiguation" => "",
            "id" => "89a675c2-3e37-3518-b83c-418bad59a85a",
            "iso-3166-1-codes" => ["XE"],
            "name" => "Europe",
            "sort-name" => "Europe",
            "type" => nil,
            "type-id" => nil
          },
          "date" => "2004-05-03"
        }
      ],
      "release-group" => %{
        "disambiguation" => "",
        "first-release-date" => "2004-05-03",
        "id" => "20790e26-98e4-3ad3-a67f-b674758b942d",
        "primary-type" => "Album",
        "primary-type-id" => "f529b476-6e62-324f-b0aa-1f3e33d313fc",
        "secondary-type-ids" => [],
        "secondary-types" => [],
        "title" => "Marbles"
      },
      "status" => "Official",
      "status-id" => "4e304316-386d-3409-af2e-78857eec5cfe",
      "text-representation" => %{"language" => "eng", "script" => "Latn"},
      "title" => "Marbles"
    }
  end
end
