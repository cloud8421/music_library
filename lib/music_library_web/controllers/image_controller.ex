defmodule MusicLibraryWeb.ImageController do
  use MusicLibraryWeb, :controller

  alias MusicLibrary.Records

  def show(conn, %{"record_id" => record_id}) do
    # TODO: better error handling
    # TODO: serve correct caching headers
    image_data = Records.get_image!(record_id)

    if image_data do
      conn
      |> put_resp_content_type("image/jpeg", "utf-8")
      |> send_resp(200, image_data)
    else
      conn |> send_resp(404, "Not found")
    end
  end
end
