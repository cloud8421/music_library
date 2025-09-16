defmodule MusicLibraryWeb.ScrobbledTracksLive.Index do
  use MusicLibraryWeb, :live_view

  import MusicLibraryWeb.PaginationComponent
  import MusicLibraryWeb.RecordComponents, only: [search_form: 1]

  alias LastFm.Track
  alias MusicLibrary.ScrobbleActivity

  @default_tracks_list_params %{
    query: "",
    page: 1,
    page_size: 200,
    order: :scrobbled_at
  }

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:current_section, :scrobble_activity)
      |> stream_configure(:tracks, dom_id: fn %Track{scrobbled_at_uts: id} -> "tracks-#{id}" end)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"scrobbled_at_uts" => id} = params) do
    track = ScrobbleActivity.get_track!(id)

    socket
    |> apply_fallback_index(params)
    |> assign(:page_title, gettext("Edit Track"))
    |> assign(:track, track)
    |> assign(:form, to_form(Track.changeset(track, %{})))
  end

  defp apply_action(socket, :index, params) do
    query = params["query"] || ""
    order = parse_order(params["order"] || "scrobbled_at")
    total_tracks = ScrobbleActivity.search_tracks_count(query)

    track_list_params =
      @default_tracks_list_params
      |> merge_query(query)
      |> merge_order(order)
      |> merge_pagination(params, total_tracks)

    load_and_assign_tracks(socket, track_list_params)
  end

  def apply_fallback_index(socket, params) do
    if get_in(socket.assigns, [:streams, :tracks]) == nil do
      socket
      |> apply_action(:index, params)
    else
      socket
    end
  end

  @impl true
  def handle_info({MusicLibraryWeb.ScrobbledTracksLive.FormComponent, {:saved, _track}}, socket) do
    {:noreply, load_and_assign_tracks(socket, socket.assigns.track_list_params)}
  end

  @impl true
  def handle_event("delete", %{"scrobbled-at-uts" => scrobbled_at_uts}, socket) do
    track = ScrobbleActivity.get_track!(scrobbled_at_uts)
    {:ok, _} = ScrobbleActivity.delete_track(track)

    {:noreply, stream_delete(socket, :tracks, track)}
  end

  def handle_event("search", %{"query" => query}, socket) do
    qs =
      @default_tracks_list_params
      |> Map.put(:query, query)
      |> Map.take([:query, :page, :page_size])

    {:noreply, push_patch(socket, to: ~p"/scrobbled-tracks?#{qs}")}
  end

  defp parse_order("scrobbled_at"), do: :scrobbled_at
  defp parse_order("title"), do: :title
  defp parse_order("artist"), do: :artist
  defp parse_order("album"), do: :album
  defp parse_order(_), do: :scrobbled_at

  defp merge_query(params, query), do: Map.put(params, :query, query)
  defp merge_order(params, order), do: Map.put(params, :order, order)

  defp merge_pagination(params, url_params, total_records) do
    page = parse_page(url_params["page"])
    page_size = parse_page_size(url_params["page_size"])

    params
    |> Map.put(:page, page)
    |> Map.put(:page_size, page_size)
    |> Map.put(:total_records, total_records)
  end

  defp parse_page(nil), do: 1

  defp parse_page(page) when is_binary(page) do
    case Integer.parse(page) do
      {num, ""} when num > 0 -> num
      _ -> 1
    end
  end

  defp parse_page(_), do: 1

  defp parse_page_size(nil), do: 200

  defp parse_page_size(page_size) when is_binary(page_size) do
    case Integer.parse(page_size) do
      {num, ""} when num in [50, 100, 200, 500] -> num
      _ -> 200
    end
  end

  defp parse_page_size(_), do: 200

  defp load_and_assign_tracks(socket, track_list_params) do
    tracks = ScrobbleActivity.list_tracks(track_list_params)
    tracks_empty? = tracks == []

    # Add total_entries for pagination component
    track_list_params_with_total =
      Map.put(track_list_params, :total_entries, track_list_params.total_records)

    socket
    |> assign(:track_list_params, track_list_params_with_total)
    |> assign(:tracks_empty?, tracks_empty?)
    |> assign(:page_title, gettext("Scrobbled Tracks"))
    |> stream(:tracks, tracks, reset: true)
  end

  def order_path(track_list_params, order) do
    qs =
      track_list_params
      |> Map.put(:order, order)
      |> Map.put(:page, 1)
      |> Map.take([:query, :page, :page_size, :order])

    ~p"/scrobbled-tracks?#{qs}"
  end

  def back_path(track_list_params) do
    qs =
      track_list_params
      |> Map.take([:query, :page, :page_size, :order])

    ~p"/scrobbled-tracks?#{qs}"
  end
end
