defmodule MusicBrainz.Fixtures.ReleaseGroup do
  @fixtures_folder Path.join([File.cwd!(), "test/support/fixtures/music_brainz"])

  def release_group_search_results do
    Path.join([@fixtures_folder, "release_group_search_results - marillion marbles.json"])
    |> File.read!()
    |> JSON.decode!()
  end

  def release_group(:mystery_of_time) do
    Path.join([@fixtures_folder, "release_group - avantasia - the mystery of time.json"])
    |> File.read!()
    |> JSON.decode!()
  end

  def release_group(:marbles) do
    Path.join([@fixtures_folder, "release_group - marillion - marbles.json"])
    |> File.read!()
    |> JSON.decode!()
  end

  def release_group(:lockdown_trilogy) do
    Path.join([
      @fixtures_folder,
      "release_group_with_includes - mariusz duda - lockdown trilogy.json"
    ])
    |> File.read!()
    |> JSON.decode!()
  end

  def release_group_releases(name) do
    rg = release_group(name)
    %{"releases" => rg["releases"]}
  end

  def release_group_id(name) do
    release_group(name) |> Map.get("id")
  end
end
