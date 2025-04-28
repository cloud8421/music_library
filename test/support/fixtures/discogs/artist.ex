defmodule Discogs.Fixtures.Artist do
  @fixtures_folder Path.join([File.cwd!(), "test/support/fixtures/discogs"])

  def get_artist do
    Path.join([@fixtures_folder, "artist - steven wilson.json"])
    |> File.read!()
    |> JSON.decode!()
  end
end
