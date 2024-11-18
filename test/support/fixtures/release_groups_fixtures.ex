defmodule MusicLibrary.ReleaseGroupsFixtures do
  @fixtures_folder Path.join([File.cwd!(), "test/support/fixtures"])

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
    Path.join([@fixtures_folder, "release_group.json"])
    |> File.read!()
    |> Jason.decode!()
  end

  def release_group_with_includes do
    Path.join([@fixtures_folder, "release_group_with_includes.json"])
    |> File.read!()
    |> Jason.decode!()
  end

  def release_id do
    release() |> Map.get("id")
  end

  def release do
    Path.join([@fixtures_folder, "release.json"])
    |> File.read!()
    |> Jason.decode!()
  end
end
