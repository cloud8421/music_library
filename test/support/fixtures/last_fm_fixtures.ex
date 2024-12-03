defmodule LastFm.Fixtures do
  @fixtures_folder Path.join([File.cwd!(), "test/support/fixtures"])

  def artist_get_info do
    Path.join([@fixtures_folder, "artist.getinfo.json"])
    |> File.read!()
    |> Jason.decode!()
  end
end
