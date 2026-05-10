defmodule MusicLibraryWeb.CollectionController do
  use MusicLibraryWeb, :controller

  alias MusicBrainz
  alias MusicLibrary.Collection
  alias MusicLibrary.Records
  alias MusicLibrary.ScrobbleActivity

  def latest(conn, _params) do
    latest_record = Collection.get_latest_record!()

    render(conn, :show, record: latest_record)
  end

  def random(conn, _params) do
    random_record = Collection.get_random_record!()

    render(conn, :show, record: random_record)
  end

  def on_this_day(conn, params) do
    current_date =
      case Map.get(params, "date") do
        nil -> Date.utc_today()
        date_string -> Date.from_iso8601!(date_string)
      end

    records_on_this_day = Collection.get_records_on_this_day(current_date)

    render(conn, :on_this_day, records: records_on_this_day)
  end

  def index(conn, params) do
    query = normalize_query(params["q"])
    limit = parse_int(params["limit"], 20)
    offset = parse_int(params["offset"], 0)

    total = Collection.search_records_count(query)

    records = Collection.search_records(query, limit: limit, offset: offset)

    render(conn, :index, total: total, limit: limit, offset: offset, records: records)
  end

  def scrobble(conn, %{"record_id" => record_id}) do
    case Records.get_record(record_id) do
      nil ->
        conn
        |> put_status(404)
        |> json(%{status: "error", reason: "not_found"})

      record ->
        do_scrobble(conn, record)
    end
  end

  defp do_scrobble(conn, record) do
    if is_nil(record.selected_release_id) or record.selected_release_id == "" do
      conn
      |> put_status(422)
      |> json(%{status: "error", reason: "no_selected_release"})
    else
      case MusicBrainz.get_release(record.selected_release_id) do
        {:ok, release} ->
          release_with_tracks = MusicBrainz.Release.from_api_response(release)

          case ScrobbleActivity.scrobble_release(
                 release_with_tracks,
                 :finished_at,
                 DateTime.utc_now()
               ) do
            {:ok, _response} ->
              json(conn, %{status: "ok"})

            {:error, :no_duration} ->
              conn
              |> put_status(422)
              |> json(%{status: "error", reason: "no_duration"})

            {:error, :no_session_key} ->
              conn
              |> put_status(503)
              |> json(%{status: "error", reason: "lastfm_not_configured"})

            {:error, _reason} ->
              conn
              |> put_status(502)
              |> json(%{status: "error", reason: "lastfm_error"})
          end

        {:error, _reason} ->
          conn
          |> put_status(502)
          |> json(%{status: "error", reason: "musicbrainz_error"})
      end
    end
  end

  defp parse_int(nil, default), do: default

  defp parse_int(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> int
      _ -> default
    end
  end

  defp parse_int(_, default), do: default

  defp normalize_query(nil), do: ""
  defp normalize_query(""), do: ""
  defp normalize_query(query), do: query
end
