defmodule MusicLibraryWeb.CoverController do
  use MusicLibraryWeb, :controller

  alias MusicLibrary.Assets
  alias MusicLibrary.Assets.Asset
  alias MusicLibrary.Records.Cover

  # 1 year in seconds
  @cache_duration 60 * 60 * 24 * 365

  def show(conn, %{"hash" => hash, "size" => size}) do
    case Assets.get(hash) do
      nil ->
        not_found(conn)

      %{content: content} ->
        # TODO: find a way to cache computation, or pre-compute thumb and store it
        {:ok, thumb_data} = Cover.resize(content, String.to_integer(size))
        hash = Asset.hash(thumb_data)

        case get_req_header(conn, "if-none-match") do
          [^hash] -> extend_cache(conn)
          _ -> respond_with_cache(conn, thumb_data, hash)
        end
    end
  end

  def show(conn, %{"hash" => hash}) do
    case Assets.get(hash) do
      nil ->
        not_found(conn)

      asset ->
        case get_req_header(conn, "if-none-match") do
          [^hash] -> extend_cache(conn)
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

  defp respond_with_cache(conn, data, etag) do
    conn
    |> put_resp_content_type("image/jpeg", "utf-8")
    |> put_resp_header("cache-control", "public, max-age=#{@cache_duration}")
    |> put_resp_header("etag", etag)
    |> send_resp(200, data)
  end
end
