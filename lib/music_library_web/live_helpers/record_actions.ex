defmodule MusicLibraryWeb.LiveHelpers.RecordActions do
  @moduledoc """
  Shared record action handlers for CollectionLive.Show and WishlistLive.Show.

  Each function takes a socket (with a `:record` assign), performs the
  operation, and returns `{:noreply, socket}` — ready to be returned
  directly from a `handle_event/3` callback.
  """

  import LiveToast, only: [put_toast: 3]
  import Phoenix.Component, only: [assign: 3]

  use Gettext, backend: MusicLibraryWeb.Gettext

  alias MusicLibrary.Chats
  alias MusicLibrary.Records
  alias MusicLibrary.Records.Similarity
  alias MusicLibraryWeb.ErrorMessages

  def refresh_musicbrainz_data(socket) do
    record = socket.assigns.record

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
           gettext("Error refreshing MusicBrainz data") <>
             ": " <> ErrorMessages.friendly_message(reason)
         )}
    end
  end

  def refresh_cover(socket) do
    record = socket.assigns.record

    case Records.refresh_cover(record) do
      {:ok, updated_record} ->
        {:noreply,
         socket
         |> put_toast(:info, gettext("Cover refreshed successfully"))
         |> assign(:record, updated_record)}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_toast(
           :error,
           gettext("Error refreshing cover") <> ": " <> ErrorMessages.friendly_message(reason)
         )}
    end
  end

  def populate_genres(socket) do
    record = socket.assigns.record

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
           gettext("Error") <> ": " <> ErrorMessages.friendly_message(reason)
         )}
    end
  end

  def extract_colors(socket) do
    record = socket.assigns.record

    case Records.extract_colors(record) do
      {:ok, updated_record} ->
        {:noreply,
         socket
         |> assign(:record, updated_record)
         |> put_toast(:info, gettext("Colors extracted"))}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_toast(
           :error,
           gettext("Error extracting colors") <> ": " <> ErrorMessages.friendly_message(reason)
         )}
    end
  end

  def handle_chats_changed(socket) do
    {:noreply,
     assign(socket, :chat_count, Chats.count_chats(:record, socket.assigns.record.musicbrainz_id))}
  end

  @doc """
  Handles a background record update. Returns the updated socket (not wrapped
  in `{:noreply, ...}`) so the caller can pipe additional assigns.
  """
  def handle_record_updated(socket, record) do
    socket
    |> put_toast(:info, gettext("Record updated in the background"))
    |> assign(:record, record)
    |> assign_embedding_text()
  end

  def assign_embedding_text(socket) do
    case Similarity.get_embedding_text(socket.assigns.record.id) do
      {:ok, text} -> assign(socket, :embedding_text, text)
      {:error, _reason} -> assign(socket, :embedding_text, gettext("Not available"))
    end
  end
end
