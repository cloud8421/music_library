defmodule MusicLibraryWeb.HealthController do
  use MusicLibraryWeb, :controller

  alias MusicLibrary.Repo

  def index(conn, _params) do
    case Repo.query("SELECT 1") do
      {:ok, _} ->
        conn
        |> put_resp_content_type("text/html")
        |> send_resp(200, "App is running")

      {:error, _} ->
        conn
        |> put_resp_content_type("text/html")
        |> send_resp(500, "App is not running")
    end
  end
end
