defmodule Discogs.Fixtures.Artist do
  @fixtures_folder Path.join([File.cwd!(), "test/support/fixtures/discogs"])

  # Cache fixtures at compile time to avoid repeated file I/O
  @get_artist Path.join([@fixtures_folder, "artist - steven wilson.json"])
              |> File.read!()
              |> JSON.decode!()

  @image_data Path.join([@fixtures_folder, "steven wilson.jpeg"])
              |> File.read!()

  def get_artist, do: @get_artist

  def image_data, do: @image_data

  def image_width, do: 225
end
