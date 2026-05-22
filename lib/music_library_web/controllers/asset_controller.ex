defmodule MusicLibraryWeb.AssetController do
  use MusicLibraryWeb, :controller

  require Logger

  alias MusicLibrary.Assets
  alias MusicLibrary.Assets.{Cache, Image, Transform}

  # 1 year in seconds
  @cache_duration 60 * 60 * 24 * 365

  def show(conn, %{"transform_payload" => payload}) do
    format = pick_format(conn)

    case Transform.decode(payload) do
      {:error, :invalid_payload} ->
        bad_request(conn)

      {:ok, transform} ->
        cache_key = Transform.canonical_key(transform)

        case cached_get(cache_key, transform, format) do
          nil ->
            not_found(conn)

          content when is_binary(content) ->
            case get_req_header(conn, "if-none-match") do
              [^payload] -> extend_cache(conn)
              _ -> respond_with_cache(conn, content, format, payload)
            end
        end
    end
  end

  defp cached_get(_cache_key, transform, _format) when is_nil(transform.hash) do
    nil
  end

  defp cached_get(cache_key, transform, format) do
    case Cache.get(cache_key, format) do
      :not_found ->
        if asset = Assets.get(transform.hash) do
          result =
            if transform.width do
              Image.resize(asset.content, transform.width, format)
            else
              Image.convert(asset.content, asset.format, format)
            end

          case result do
            {:ok, image_data} ->
              Cache.set(cache_key, format, image_data)
              image_data

            {:error, reason} ->
              Logger.error("Asset transform failed for #{transform.hash}: #{inspect(reason)}")
              nil
          end
        end

      {:found, content} ->
        content
    end
  end

  defp pick_format(conn) do
    accept =
      case get_req_header(conn, "accept") do
        [] -> ""
        [value] -> value
      end

    if String.contains?(accept, "image/webp") do
      "image/webp"
    else
      "image/jpeg"
    end
  end

  defp bad_request(conn) do
    conn
    |> put_status(:bad_request)
    |> text("Bad request")
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

  # Format is always resolved to either "image/webp" or "image/jpeg" in
  # pick_format/1, so it's safe.
  # sobelow_skip ["XSS.ContentType", "XSS.SendResp"]
  defp respond_with_cache(conn, data, format, etag) do
    conn
    |> put_resp_content_type(format, "utf-8")
    |> put_resp_header("cache-control", "public, max-age=#{@cache_duration}")
    |> put_resp_header("etag", etag)
    |> send_resp(200, data)
  end
end
