defmodule MusicLibraryWeb.ImageController do
  use MusicLibraryWeb, :controller

  alias MusicLibrary.Records

  def show(conn, %{"record_id" => record_id}) do
    case Records.get_cover(record_id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> text("Not found")

      %{cover_data: cover_data, cover_hash: etag} ->
        case get_req_header(conn, "if-none-match") do
          [^etag] ->
            send_resp(conn, 304, "")

          _ ->
            conn
            |> put_resp_content_type("image/jpeg", "utf-8")
            |> put_resp_header("etag", etag)
            |> send_resp(200, cover_data)
        end
    end
  end
end
