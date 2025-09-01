defmodule MusicLibraryWeb.ArtistController do
  use MusicLibraryWeb, :controller

  alias MusicLibrary.Artists

  # 1 year in seconds
  @cache_duration 60 * 60 * 24 * 365

  def image(conn, %{"musicbrainz_id" => artist_id}) do
    case Artists.get_image(artist_id) do
      nil ->
        not_found(conn)

      %{image_data: image_data, image_data_hash: etag} ->
        case get_req_header(conn, "if-none-match") do
          [^etag] -> extend_cache(conn)
          _ -> respond_with_cache(conn, image_data, etag)
        end
    end
  end

  defp not_found(conn) do
    conn
    |> put_status(:not_found)
    |> text("Not found")
  end

  defp extend_cache(conn) do
    conn
    |> put_resp_header("cache-control", "public, max-age=#{@cache_duration}")
    |> send_resp(304, "")
  end

  defp respond_with_cache(conn, image_data, etag) do
    conn
    |> put_resp_content_type("image/jpeg", "utf-8")
    |> put_resp_header("cache-control", "public, max-age=#{@cache_duration}")
    |> put_resp_header("etag", etag)
    |> send_resp(200, image_data)
  end
end
