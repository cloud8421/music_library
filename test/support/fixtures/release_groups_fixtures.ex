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
      "releases" => [
        %{
          "barcode" => "",
          "country" => "XE",
          "date" => "2004-05-03",
          "disambiguation" => "non‐deluxe double CD with o‐card",
          "genres" => [],
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
          "status" => "Official",
          "status-id" => "4e304316-386d-3409-af2e-78857eec5cfe",
          "text-representation" => %{"language" => "eng", "script" => "Latn"},
          "title" => "Marbles"
        },
        %{
          "barcode" => "",
          "country" => "GB",
          "date" => "2004-05-03",
          "disambiguation" => "limited deluxe campaign edition",
          "genres" => [],
          "id" => "3f1cc80f-4507-48a9-899c-c1bda83280c2",
          "packaging" => "Other",
          "packaging-id" => "815b7785-8284-3926-8f04-e48bc6c4d102",
          "quality" => "normal",
          "release-events" => [
            %{
              "area" => %{
                "disambiguation" => "",
                "id" => "8a754a16-0027-3a29-b6d7-2b40ea0481ed",
                "iso-3166-1-codes" => ["GB"],
                "name" => "United Kingdom",
                "sort-name" => "United Kingdom",
                "type" => nil,
                "type-id" => nil
              },
              "date" => "2004-05-03"
            }
          ],
          "status" => "Official",
          "status-id" => "4e304316-386d-3409-af2e-78857eec5cfe",
          "text-representation" => %{"language" => "eng", "script" => "Latn"},
          "title" => "Marbles"
        },
        %{
          "barcode" => "5037300650128",
          "country" => "GB",
          "date" => "2004-05-03",
          "disambiguation" => "",
          "genres" => [],
          "id" => "d3f9b9e2-73f5-4b47-a2a7-2c2199aad608",
          "packaging" => "Jewel Case",
          "packaging-id" => "ec27701a-4a22-37f4-bfac-6616e0f9750a",
          "quality" => "normal",
          "release-events" => [
            %{
              "area" => %{
                "disambiguation" => "",
                "id" => "8a754a16-0027-3a29-b6d7-2b40ea0481ed",
                "iso-3166-1-codes" => ["GB"],
                "name" => "United Kingdom",
                "sort-name" => "United Kingdom",
                "type" => nil,
                "type-id" => nil
              },
              "date" => "2004-05-03"
            }
          ],
          "status" => "Official",
          "status-id" => "4e304316-386d-3409-af2e-78857eec5cfe",
          "text-representation" => %{"language" => "eng", "script" => "Latn"},
          "title" => "Marbles"
        },
        %{
          "barcode" => "",
          "country" => "RU",
          "date" => "2004",
          "disambiguation" => "",
          "genres" => [],
          "id" => "2c4ecd84-7a84-4f42-a600-2f00ed8978c9",
          "packaging" => "Jewel Case",
          "packaging-id" => "ec27701a-4a22-37f4-bfac-6616e0f9750a",
          "quality" => "normal",
          "release-events" => [
            %{
              "area" => %{
                "disambiguation" => "",
                "id" => "1f1fc3a4-9500-39b8-9f10-f0a465557eef",
                "iso-3166-1-codes" => ["RU"],
                "name" => "Russia",
                "sort-name" => "Russia",
                "type" => nil,
                "type-id" => nil
              },
              "date" => "2004"
            }
          ],
          "status" => "Bootleg",
          "status-id" => "1156806e-d06a-38bd-83f0-cf2284a808b9",
          "text-representation" => %{"language" => "eng", "script" => "Latn"},
          "title" => "Marbles"
        },
        %{
          "barcode" => "803341127920",
          "country" => "US",
          "date" => "2004",
          "disambiguation" => "",
          "genres" => [],
          "id" => "ab151aa6-7538-4e93-be60-eded52b5b7b7",
          "packaging" => nil,
          "packaging-id" => nil,
          "quality" => "normal",
          "release-events" => [
            %{
              "area" => %{
                "disambiguation" => "",
                "id" => "489ce91b-6658-3307-9877-795b68554c98",
                "iso-3166-1-codes" => ["US"],
                "name" => "United States",
                "sort-name" => "United States",
                "type" => nil,
                "type-id" => nil
              },
              "date" => "2004"
            }
          ],
          "status" => "Official",
          "status-id" => "4e304316-386d-3409-af2e-78857eec5cfe",
          "text-representation" => %{"language" => "eng", "script" => "Latn"},
          "title" => "Marbles"
        },
        %{
          "barcode" => "636551597210",
          "country" => "GB",
          "date" => "2011-04-25",
          "disambiguation" => "",
          "genres" => [],
          "id" => "b94bbd1f-ae5d-4e7b-98ff-28bfe135f20c",
          "packaging" => "Cardboard/Paper Sleeve",
          "packaging-id" => "f7101ce3-0384-39ce-9fde-fbbd0044d35f",
          "quality" => "normal",
          "release-events" => [
            %{
              "area" => %{
                "disambiguation" => "",
                "id" => "8a754a16-0027-3a29-b6d7-2b40ea0481ed",
                "iso-3166-1-codes" => ["GB"],
                "name" => "United Kingdom",
                "sort-name" => "United Kingdom",
                "type" => nil,
                "type-id" => nil
              },
              "date" => "2011-04-25"
            }
          ],
          "status" => "Official",
          "status-id" => "4e304316-386d-3409-af2e-78857eec5cfe",
          "text-representation" => %{"language" => "eng", "script" => "Latn"},
          "title" => "Marbles"
        },
        %{
          "barcode" => "636551597227",
          "country" => "GB",
          "date" => "2011-04-25",
          "disambiguation" => "",
          "genres" => [],
          "id" => "4b9fe13b-4837-4c02-9368-e97ba6f5a086",
          "packaging" => "Digibook",
          "packaging-id" => "9f2e13bc-f84f-428a-8342-fd86ece7fc4d",
          "quality" => "normal",
          "release-events" => [
            %{
              "area" => %{
                "disambiguation" => "",
                "id" => "8a754a16-0027-3a29-b6d7-2b40ea0481ed",
                "iso-3166-1-codes" => ["GB"],
                "name" => "United Kingdom",
                "sort-name" => "United Kingdom",
                "type" => nil,
                "type-id" => nil
              },
              "date" => "2011-04-25"
            }
          ],
          "status" => "Official",
          "status-id" => "4e304316-386d-3409-af2e-78857eec5cfe",
          "text-representation" => %{"language" => "eng", "script" => "Latn"},
          "title" => "Marbles"
        },
        %{
          "barcode" => "636551808613",
          "country" => "XE",
          "date" => "2017",
          "disambiguation" => "",
          "genres" => [],
          "id" => "a4b02377-0b5e-448e-9cd6-5500c0378523",
          "packaging" => "Other",
          "packaging-id" => "815b7785-8284-3926-8f04-e48bc6c4d102",
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
              "date" => "2017"
            }
          ],
          "status" => "Official",
          "status-id" => "4e304316-386d-3409-af2e-78857eec5cfe",
          "text-representation" => %{"language" => "eng", "script" => "Latn"},
          "title" => "Marbles"
        },
        %{
          "barcode" => "859724565117",
          "country" => "XW",
          "date" => "",
          "disambiguation" => "",
          "genres" => [],
          "id" => "f3937bc5-b99f-443a-9609-a404201f21ca",
          "packaging" => "None",
          "packaging-id" => "119eba76-b343-3e02-a292-f0f00644bb9b",
          "quality" => "normal",
          "release-events" => [
            %{
              "area" => %{
                "disambiguation" => "",
                "id" => "525d4e18-3d00-31b9-a58b-a146a916de8f",
                "iso-3166-1-codes" => ["XW"],
                "name" => "[Worldwide]",
                "sort-name" => "[Worldwide]",
                "type" => nil,
                "type-id" => nil
              },
              "date" => ""
            }
          ],
          "status" => "Official",
          "status-id" => "4e304316-386d-3409-af2e-78857eec5cfe",
          "text-representation" => %{"language" => "eng", "script" => "Latn"},
          "title" => "Marbles"
        }
      ],
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
