defmodule MusicLibraryWeb.LiveHelpers.RecordShow do
  @moduledoc """
  Shared show-page helpers for collection and wishlist record LiveViews.

  The helpers keep common record loading, event handling, async scrobble
  handling, and background-update behaviour in one place while allowing each
  LiveView to compose page-specific assigns and UI around the shared flow.
  """

  require Logger

  import LiveToast, only: [put_toast: 3]
  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView, only: [push_navigate: 2, start_async: 3]

  use Gettext, backend: MusicLibraryWeb.Gettext

  alias MusicLibrary.{Chats, Records, RecordSets, ScrobbleActivity}
  alias MusicLibraryWeb.ErrorMessages
  alias MusicLibraryWeb.LiveHelpers.RecordActions

  def assign_common_record(socket, id, section_title) do
    RecordActions.manage_subscription(socket, id)

    record = Records.get_record!(id)
    record_sets = RecordSets.list_record_sets_for_record(record.id)

    socket
    |> assign(:page_title, page_title(socket.assigns.live_action, record, section_title))
    |> assign(:record, record)
    |> assign(:record_sets, record_sets)
    |> assign(:chat_count, Chats.count_chats(:record, record.musicbrainz_id))
    |> RecordActions.assign_embedding_text()
  end

  def handle_common_event("refresh_musicbrainz_data", socket) do
    RecordActions.refresh_musicbrainz_data(socket)
  end

  def handle_common_event("refresh_cover", socket) do
    RecordActions.refresh_cover(socket)
  end

  def handle_common_event("populate_genres", socket) do
    RecordActions.populate_genres(socket)
  end

  def handle_common_event("extract_colors", socket) do
    RecordActions.extract_colors(socket)
  end

  def delete_record(socket, path) do
    {:ok, _} = Records.delete_record(socket.assigns.record)

    {:noreply, push_navigate(socket, to: path)}
  end

  def scrobble_release(socket) do
    record = socket.assigns.record

    {:noreply,
     start_async(socket, :scrobble_release, fn ->
       with {:ok, release} <- MusicBrainz.get_release(record.selected_release_id) do
         release_with_tracks = MusicBrainz.Release.from_api_response(release)

         ScrobbleActivity.scrobble_release(release_with_tracks, :finished_at, DateTime.utc_now())
       end
     end)}
  end

  def handle_scrobble_release({:ok, {:ok, _result}}, socket) do
    {:noreply, put_toast(socket, :info, gettext("Release scrobbled successfully"))}
  end

  def handle_scrobble_release({:ok, {:error, reason}}, socket) do
    {:noreply,
     put_toast(
       socket,
       :error,
       gettext("Error scrobbling release") <> ": " <> ErrorMessages.friendly_message(reason)
     )}
  end

  def handle_scrobble_release({:exit, reason}, socket) do
    Logger.error("Scrobble release failed: #{inspect(reason)}")

    {:noreply,
     put_toast(
       socket,
       :error,
       gettext("Error scrobbling release") <> ": " <> ErrorMessages.friendly_message(reason)
     )}
  end

  def handle_saved_record(socket, record, after_assign \\ &Function.identity/1) do
    {:noreply,
     socket
     |> assign(:record, record)
     |> after_assign.()
     |> RecordActions.assign_embedding_text()}
  end

  def handle_chats_changed(socket) do
    RecordActions.handle_chats_changed(socket)
  end

  def handle_release_loaded(socket) do
    {:noreply, socket}
  end

  def handle_record_update(socket, record, after_update \\ &Function.identity/1) do
    cond do
      record.id != socket.assigns.record.id ->
        {:noreply, socket}

      socket.assigns.live_action == :edit ->
        {:noreply,
         socket
         |> put_toast(
           :warning,
           gettext(
             "Record was updated in the background. Your edits may be stale — save and re-open to see the latest data."
           )
         )}

      true ->
        {:noreply,
         socket
         |> RecordActions.handle_record_updated(record)
         |> after_update.()}
    end
  end

  defp page_title(action, record, section_title) do
    Enum.join(
      [
        Records.Record.artist_names(record),
        "-",
        record.title,
        "·",
        title_segment(action),
        "·",
        section_title
      ],
      " "
    )
  end

  defp title_segment(:show), do: gettext("Details")
  defp title_segment(:edit), do: gettext("Edit")
  defp title_segment(:add_to_set), do: gettext("Add to sets")
end
