defmodule MusicBrainz.Fixtures.Release do
  @fixtures_folder Path.join([File.cwd!(), "test/support/fixtures/music_brainz"])

  def releases(:queen_greatest_hits) do
    Path.join([@fixtures_folder, "releases - queen - greatest hits.json"])
    |> File.read!()
    |> Jason.decode!()
    |> Map.get("releases")
  end

  def release(:mystery_of_time) do
    Path.join([@fixtures_folder, "release - avantasia - the mystery of time.json"])
    |> File.read!()
    |> JSON.decode!()
  end

  def release(:marbles) do
    Path.join([@fixtures_folder, "release - marillion - marbles.json"])
    |> File.read!()
    |> JSON.decode!()
  end

  def release_id(name) do
    release(name) |> Map.get("id")
  end
end
