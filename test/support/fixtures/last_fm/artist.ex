defmodule LastFm.Fixtures.Artist do
  @fixtures_folder Path.join([File.cwd!(), "test/support/fixtures/last_fm"])

  alias LastFm.Artist

  def get_info do
    Path.join([@fixtures_folder, "artist.getinfo.json"])
    |> File.read!()
    |> JSON.decode!()
    |> Map.get("artist")
    |> Artist.from_api_response()
  end
end
