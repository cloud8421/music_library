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

  def import_musicbrainz_data(record) do
    with {:ok, data} <- musicbrainz().get_release_group(record.musicbrainz_id) do
      record
      |> Record.add_musicbrainz_data(data)
      |> Repo.update!()
    end
  end

  def update_release_ids do
    Record
    |> Repo.all()
    |> Enum.each(&update_release_ids/1)
  end

  def update_release_ids(record) do
    record
    |> Record.update_release_ids()
    |> Repo.update!()
  end

  defp musicbrainz do
    Application.get_env(:music_library, :musicbrainz, MusicBrainz.APIImpl)
  end
end
