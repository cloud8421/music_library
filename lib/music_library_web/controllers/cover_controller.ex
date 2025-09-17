defmodule MusicLibraryWeb.CoverController do
  use MusicLibraryWeb, :controller

  alias MusicLibrary.Assets
  alias MusicLibrary.Assets.{Cache, Transform}
  alias MusicLibrary.Records.Cover

  # 1 year in seconds
  @cache_duration 60 * 60 * 24 * 365

  def show(conn, %{"transform_payload" => payload}) do
    format = pick_format(conn)
    transform = Transform.decode!(payload)

    case cached_get(payload, transform, format) do
      nil ->
        not_found(conn)

      content when is_binary(content) ->
        case get_req_header(conn, "if-none-match") do
          [^payload] -> extend_cache(conn)
          _ -> respond_with_cache(conn, content, format, payload)
        end
    end
  end

  defp cached_get(payload, transform, format) do
    case Cache.get(payload, format) do
      :not_found ->
        if asset = Assets.get(transform.hash) do
          image_data =
            if transform.width do
              # TODO: find a way to cache computation, or pre-compute thumb and store it
              {:ok, data} = Cover.resize(asset.content, transform.width, format)
              data
            else
              {:ok, data} = Cover.convert(asset.content, asset.format, format)
              data
            end

          Cache.set(payload, format, image_data)
          image_data
        end

      {:found, content} ->
        content
    end
  end

  defp pick_format(conn) do
    case get_req_header(conn, "accept") do
      ["image/webp" <> _] -> "image/webp"
      _ -> "image/jpeg"
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

  defp respond_with_cache(conn, data, format, etag) do
    conn
    |> put_resp_content_type(format, "utf-8")
    |> put_resp_header("cache-control", "public, max-age=#{@cache_duration}")
    |> put_resp_header("etag", etag)
    |> send_resp(200, data)
  end
end
