defmodule MusicLibrary.Records.Batch do
  require Logger

  alias MusicLibrary.Records.Record
  alias MusicLibrary.Repo

  def refresh_musicbrainz_data do
    Record
    |> Repo.all()
    |> Enum.each(fn r ->
      import_musicbrainz_data(r)
      Process.sleep(1000)
    end)
  end

  defp import_musicbrainz_data(record) do
    with {:ok, data} <- musicbrainz().get_release_group(record.musicbrainz_id) do
      record
      |> Record.add_musicbrainz_data(data)
      |> Repo.update!()
    end
  end

  defp musicbrainz do
    Application.get_env(:music_library, :musicbrainz, MusicBrainz.APIImpl)
  end
end
