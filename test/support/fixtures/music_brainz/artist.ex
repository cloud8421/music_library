defmodule MusicBrainz.Fixtures.Artist do
  @fixtures_folder Path.join([File.cwd!(), "test/support/fixtures/music_brainz"])

  # Cache fixtures at compile time to avoid repeated file I/O
  @get_artist Path.join([@fixtures_folder, "artist - steven wilson.json"])
              |> File.read!()
              |> JSON.decode!()

  def get_artist, do: @get_artist
end
