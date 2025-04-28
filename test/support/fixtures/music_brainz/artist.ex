defmodule MusicBrainz.Fixtures.Artist do
  @fixtures_folder Path.join([File.cwd!(), "test/support/fixtures/music_brainz"])

  def get_artist do
    Path.join([@fixtures_folder, "artist - steven wilson.json"])
    |> File.read!()
    |> JSON.decode!()
  end
end
