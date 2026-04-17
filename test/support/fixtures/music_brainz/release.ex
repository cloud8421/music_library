defmodule MusicBrainz.Fixtures.Release do
  @fixtures_folder Path.join([File.cwd!(), "test/support/fixtures/music_brainz"])

  # Cache JSON fixtures at compile time to avoid repeated file I/O
  @external_resource Path.join([@fixtures_folder, "releases - queen - greatest hits.json"])
  @releases_queen_greatest_hits Path.join([
                                  @fixtures_folder,
                                  "releases - queen - greatest hits.json"
                                ])
                                |> File.read!()
                                |> JSON.decode!()

  @external_resource Path.join([@fixtures_folder, "releases - marillion - marbles.json"])
  @releases_marbles Path.join([@fixtures_folder, "releases - marillion - marbles.json"])
                    |> File.read!()
                    |> JSON.decode!()

  @external_resource Path.join([
                       @fixtures_folder,
                       "release - avantasia - the mystery of time.json"
                     ])
  @release_mystery_of_time Path.join([
                             @fixtures_folder,
                             "release - avantasia - the mystery of time.json"
                           ])
                           |> File.read!()
                           |> JSON.decode!()

  @external_resource Path.join([@fixtures_folder, "release - marillion - marbles.json"])
  @release_marbles Path.join([@fixtures_folder, "release - marillion - marbles.json"])
                   |> File.read!()
                   |> JSON.decode!()

  @external_resource Path.join([
                       @fixtures_folder,
                       "release_with_media - marillion - marbles.json"
                     ])
  @release_with_media_marbles Path.join([
                                @fixtures_folder,
                                "release_with_media - marillion - marbles.json"
                              ])
                              |> File.read!()
                              |> JSON.decode!()

  def releases(:queen_greatest_hits), do: @releases_queen_greatest_hits
  def releases(:marbles), do: @releases_marbles

  def release(:mystery_of_time), do: @release_mystery_of_time
  def release(:marbles), do: @release_marbles

  def release_with_media(:marbles), do: @release_with_media_marbles

  def release_id(name) do
    release(name) |> Map.get("id")
  end
end
