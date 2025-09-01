defmodule MusicLibraryWeb.CoverController do
  use MusicLibraryWeb, :controller

  alias MusicLibrary.Assets
  alias MusicLibrary.Records
  alias MusicLibrary.Records.Cover

  # 1 year in seconds
  @cache_duration 60 * 60 * 24 * 365

  def show(conn, %{"record_id" => record_id, "size" => size}) do
    case Records.get_cover(record_id) do
      nil ->
        not_found(conn)

      %{cover_data: cover_data} ->
        # TODO: find a way to cache computation, or pre-compute thumb and store it
        {:ok, thumb_data} = Cover.resize(cover_data, String.to_integer(size))
        hash = Cover.hash(thumb_data)

        case get_req_header(conn, "if-none-match") do
          [^hash] -> extend_cache(conn)
          _ -> respond_with_cache(conn, thumb_data, hash)
        end
    end
  end

  def show(conn, %{"record_id" => record_id}) do
    case Records.get_cover(record_id) do
      nil ->
        not_found(conn)

      %{cover_hash: etag} ->
        asset = Assets.get(etag)

        case get_req_header(conn, "if-none-match") do
          [^etag] -> extend_cache(conn)
          _ -> respond_with_cache(conn, asset)
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

  defp respond_with_cache(conn, asset) do
    conn
    |> put_resp_content_type(asset.format, "utf-8")
    |> put_resp_header("cache-control", "public, max-age=#{@cache_duration}")
    |> put_resp_header("etag", asset.hash)
    |> send_resp(200, asset.content)
  end

  defp respond_with_cache(conn, cover_data, etag) do
    conn
    |> put_resp_content_type("image/jpeg", "utf-8")
    |> put_resp_header("cache-control", "public, max-age=#{@cache_duration}")
    |> put_resp_header("etag", etag)
    |> send_resp(200, cover_data)
  end
end
