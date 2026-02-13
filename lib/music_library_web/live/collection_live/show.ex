defmodule MusicLibraryWeb.CollectionLive.Show do
  use MusicLibraryWeb, :live_view

  import MusicLibrary.ScrobbleActivity, only: [localize_scrobbled_at: 2]

  import MusicLibraryWeb.RecordComponents,
    only: [
      format_label: 1,
      type_label: 1,
      release_summary: 1,
      artist_links: 1,
      record_colors: 1,
      record_cover: 1,
      release_list: 1,
      similar_records: 1
    ]

  alias MusicLibrary.{Records, RecordSets, ScrobbleActivity}
  alias MusicLibrary.Records.Similarity
  alias MusicLibrary.RecordSets.RecordSet
  alias Phoenix.LiveView.JS

  @impl true
  def mount(%{"id" => record_id}, _session, socket) do
    if connected?(socket) do
      Records.subscribe(record_id)
    end

    {:ok,
     socket
     |> assign(:current_section, :collection)
     |> assign(:can_scrobble?, ScrobbleActivity.can_scrobble?())
     |> assign(:release_with_tracks, nil)}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    record = Records.get_record!(id)
    last_listened_track = Records.get_last_listened_track(record)
    play_count = Records.play_count(record) || 0

    socket =
      if record.selected_release_id do
        socket
      else
        socket
      end

    record_sets = RecordSets.list_record_sets_for_record(record.id)

    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action, record))
     |> assign(:record, record)
     |> assign(:last_listened_track, last_listened_track)
     |> assign(:play_count, play_count)
     |> assign(:record_sets, record_sets)
     |> assign_embedding_text()
     |> assign_similar_records()}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    record = Records.get_record!(id)
    {:ok, _} = Records.delete_record(record)

    {:noreply, push_navigate(socket, to: ~p"/collection")}
  end

  def handle_event("refresh_musicbrainz_data", %{"id" => id}, socket) do
    record = Records.get_record!(id)

    case Records.refresh_musicbrainz_data(record) do
      {:ok, updated_record} ->
        {:noreply,
         socket
         |> put_toast(:info, gettext("MusicBrainz data refreshed successfully"))
         |> assign(:record, updated_record)}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_toast(
           :error,
           gettext("Error refreshing MusicBrainz data") <> "," <> inspect(reason)
         )}
    end
  end

  def handle_event("populate_genres", %{"id" => id}, socket) do
    record = Records.get_record!(id)

    case Records.populate_genres_async(record) do
      {:ok, _worker} ->
        {:noreply,
         socket
         |> put_toast(:info, gettext("In progress - record will update automatically"))}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_toast(
           :error,
           gettext("Error") <> "," <> inspect(reason)
         )}
    end
  end

  def handle_event("refresh_cover", %{"id" => id}, socket) do
    record = Records.get_record!(id)

    case Records.refresh_cover(record) do
      {:ok, record} ->
        {:noreply,
         socket
         |> assign(:record, record)
         |> put_toast(:info, gettext("Cover refreshed successfully"))}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_toast(
           :error,
           gettext("Error refreshing cover") <> "," <> inspect(reason)
         )}
    end
  end

  def handle_event("extract_colors", %{"id" => id, "method" => method}, socket) do
    record = Records.get_record!(id)
    method = String.to_existing_atom(method)

    case Records.extract_colors_async(record, method) do
      {:ok, _worker} ->
        {:noreply,
         socket
         |> put_toast(:info, gettext("In progress - record will update automatically"))}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_toast(
           :error,
           gettext("Error") <> "," <> inspect(reason)
         )}
    end
  end

  def handle_event("regenerate_embeddings", %{"id" => id}, socket) do
    record = Records.get_record!(id)

    case Similarity.generate_embedding_async(record) do
      {:ok, _worker} ->
        {:noreply,
         socket
         |> put_toast(:info, gettext("In progress - record will update automatically"))}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_toast(
           :error,
           gettext("Error") <> "," <> inspect(reason)
         )}
    end
  end

  @impl true
  def handle_info({MusicLibraryWeb.Components.RecordForm, {:saved, record}}, socket) do
    {:noreply,
     socket
     |> assign(:record, record)
     |> assign_similar_records()
     |> assign_embedding_text()}
  end

  @impl true
  def handle_info({:update, record}, socket) do
    {:noreply,
     socket
     |> put_toast(:info, gettext("Record updated in the background"))
     |> assign(:record, record)
     |> assign_similar_records()
     |> assign_embedding_text()}
  end

  def page_title(:show, record) do
    Enum.join(
      [
        Records.Record.artist_names(record),
        "-",
        record.title,
        "·",
        gettext("Details"),
        "·",
        gettext("Collection")
      ],
      " "
    )
  end

  def page_title(action, record) do
    Enum.join(
      [
        Records.Record.artist_names(record),
        "-",
        record.title,
        "·",
        title_segment(action),
        "·",
        gettext("Collection")
      ],
      " "
    )
  end

  defp title_segment(:show), do: gettext("Show")
  defp title_segment(:edit), do: gettext("Edit")

  defp assign_similar_records(socket) do
    similar_records =
      Similarity.find_similar(socket.assigns.record.id, limit: 6, scope: :collection)

    assign(socket, :similar_records, similar_records)
  end

  defp assign_embedding_text(socket) do
    case Similarity.get_embedding_text(socket.assigns.record.id) do
      {:ok, text} ->
        assign(socket, :embedding_text, text)

      {:error, _reason} ->
        assign(socket, :embedding_text, gettext("Not available"))
    end
  end
end
