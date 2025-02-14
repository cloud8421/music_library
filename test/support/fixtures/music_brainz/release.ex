defmodule MusicBrainz.Fixtures.Release do
  @fixtures_folder Path.join([File.cwd!(), "test/support/fixtures/music_brainz"])

  def releases(:queen_greatest_hits) do
    Path.join([@fixtures_folder, "releases - queen - greatest hits.json"])
    |> File.read!()
    |> Jason.decode!()
    |> Map.get("releases")
  end
end
