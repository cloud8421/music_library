defmodule LastFm.Fixtures.Artist do
  @fixtures_folder Path.join([File.cwd!(), "test/support/fixtures/last_fm"])

  # Cache fixtures at compile time to avoid repeated file I/O
  @get_info Path.join([@fixtures_folder, "artist.getinfo.json"])
            |> File.read!()
            |> JSON.decode!()

  def get_info, do: @get_info

  def get_similar_artists do
    %{"similarartists" => %{"artist" => []}}
  end
end
