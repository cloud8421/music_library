defmodule MusicLibraryWeb.ArchiveController do
  use MusicLibraryWeb, :controller

  def backup(conn, _params) do
    database_path = database_path()
    current_time = DateTime.utc_now()
    file_name = "music_library_#{DateTime.to_unix(current_time)}.db"

    send_download(conn, {:file, database_path},
      filename: file_name,
      content_type: "application/x-sqlite3"
    )
  end

  defp database_path do
    Application.get_env(:music_library, MusicLibrary.Repo)[:database]
  end
end
