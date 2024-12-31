defmodule MusicLibraryWeb.CoverController do
  use MusicLibraryWeb, :controller

  alias MusicLibrary.Records
  alias MusicLibrary.Records.Cover

  def show(conn, %{"record_id" => record_id, "size" => size}) do
    case Records.get_cover(record_id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> text("Not found")

      %{cover_data: cover_data} ->
        {:ok, thumb_data} = Cover.resize(cover_data, String.to_integer(size))
        hash = :crypto.hash(:sha256, thumb_data) |> Base.encode16()

        case get_req_header(conn, "if-none-match") do
          [^hash] ->
            conn
            # 24 hours
            |> put_resp_header("cache-control", "public, max-age=86400")
            |> send_resp(304, "")

          _ ->
            conn
            |> put_resp_content_type("image/jpeg", "utf-8")
            # 24 hours
            |> put_resp_header("cache-control", "public, max-age=86400")
            |> put_resp_header("etag", hash)
            |> send_resp(200, thumb_data)
        end
    end
  end

  def show(conn, %{"record_id" => record_id}) do
    case Records.get_cover(record_id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> text("Not found")

      %{cover_data: cover_data, cover_hash: etag} ->
        case get_req_header(conn, "if-none-match") do
          [^etag] ->
            conn
            # 24 hours
            |> put_resp_header("cache-control", "public, max-age=86400")
            |> send_resp(304, "")

          _ ->
            conn
            |> put_resp_content_type("image/jpeg", "utf-8")
            # 24 hours
            |> put_resp_header("cache-control", "public, max-age=86400")
            |> put_resp_header("etag", etag)
            |> send_resp(200, cover_data)
        end
    end
  end
end
