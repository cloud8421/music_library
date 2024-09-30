defmodule MusicLibraryWeb.ImageController do
  use MusicLibraryWeb, :controller

  alias MusicLibrary.Records

  def show(conn, %{"record_id" => record_id}) do
    case Records.get_image!(record_id) do
      nil ->
        send_resp(conn, 404, "Not found")

      %{image_data: image_data, image_data_hash: etag} ->
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
