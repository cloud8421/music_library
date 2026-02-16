defmodule MusicBrainz.Fixtures.ReleaseGroup do
  @fixtures_folder Path.join([File.cwd!(), "test/support/fixtures/music_brainz"])

  # Cache JSON fixtures at compile time to avoid repeated file I/O
  @release_group_search_results Path.join([
                                  @fixtures_folder,
                                  "release_group_search_results - marillion - marbles.json"
                                ])
                                |> File.read!()
                                |> JSON.decode!()

  @mystery_of_time Path.join([
                     @fixtures_folder,
                     "release_group - avantasia - the mystery of time.json"
                   ])
                   |> File.read!()
                   |> JSON.decode!()

  @marbles Path.join([@fixtures_folder, "release_group - marillion - marbles.json"])
           |> File.read!()
           |> JSON.decode!()

  @lockdown_trilogy Path.join([
                      @fixtures_folder,
                      "release_group_with_includes - mariusz duda - lockdown trilogy.json"
                    ])
                    |> File.read!()
                    |> JSON.decode!()

  def release_group_search_results, do: @release_group_search_results

  def release_group(:mystery_of_time), do: @mystery_of_time
  def release_group(:marbles), do: @marbles
  def release_group(:lockdown_trilogy), do: @lockdown_trilogy

  def release_group_releases(name) do
    rg = release_group(name)
    %{"releases" => rg["releases"]}
  end

  def release_group_id(name) do
    release_group(name) |> Map.get("id")
  end
end
