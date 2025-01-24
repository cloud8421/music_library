defmodule LastFm.Fixtures do
  @fixtures_folder Path.join([File.cwd!(), "test/support/fixtures"])

  alias LastFm.Artist

  def artist_get_info do
    Path.join([@fixtures_folder, "artist.getinfo.json"])
    |> File.read!()
    |> JSON.decode!()
    |> Map.get("artist")
    |> Artist.from_api_response()
  end
end
