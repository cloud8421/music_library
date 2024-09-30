defmodule MusicLibraryWeb.ImageController do
  use MusicLibraryWeb, :controller

  alias MusicLibrary.Records

  def show(conn, %{"record_id" => record_id}) do
    case Records.get_image!(record_id) do
      nil ->
        send_resp(conn, 404, "Not found")

      image_data ->
        # TODO: move hash result to database
        etag = :crypto.hash(:sha256, image_data) |> Base.encode16()

        case get_req_header(conn, "if-none-match") do
          [^etag] ->
            send_resp(conn, 304, "")

          _ ->
            conn
            |> put_resp_content_type("image/jpeg", "utf-8")
            |> put_resp_header("etag", etag)
            |> send_resp(200, image_data)
        end
    end
  end
end
