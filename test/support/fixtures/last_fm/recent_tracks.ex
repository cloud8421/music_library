defmodule LastFm.Fixtures.RecentTracks do
  @fixtures_folder Path.join([File.cwd!(), "test/support/fixtures/last_fm"])

  @external_resource Path.join([@fixtures_folder, "user.getrecenttracks.json"])
  @get Path.join([@fixtures_folder, "user.getrecenttracks.json"])
       |> File.read!()
       |> JSON.decode!()

  def get, do: @get
end
