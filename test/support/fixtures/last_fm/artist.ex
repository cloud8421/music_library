defmodule LastFm.Fixtures.Artist do
  @fixtures_folder Path.join([File.cwd!(), "test/support/fixtures/last_fm"])

  def get_info do
    Path.join([@fixtures_folder, "artist.getinfo.json"])
    |> File.read!()
    |> JSON.decode!()
  end

  def get_similar_artists do
    %{"similarartists" => %{"artist" => []}}
  end
end
