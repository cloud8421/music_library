defmodule Discogs.Fixtures.Artist do
  @fixtures_folder Path.join([File.cwd!(), "test/support/fixtures/discogs"])

  def get_artist do
    Path.join([@fixtures_folder, "artist - steven wilson.json"])
    |> File.read!()
    |> JSON.decode!()
  end

  def image_data do
    Path.join([@fixtures_folder, "steven wilson.jpeg"])
    |> File.read!()
  end

  def image_width, do: 225
end
