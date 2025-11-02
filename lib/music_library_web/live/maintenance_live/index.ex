defmodule MusicLibraryWeb.MaintenanceLive.Index do
  use MusicLibraryWeb, :live_view

  require Logger

  alias MusicLibrary.Records.Batch
  alias MusicLibrary.Repo

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       page_title: gettext("Maintenance"),
       current_section: :maintenance
     )}
  end

  def handle_event("refresh_records_musicbrainz_data", _params, socket) do
    Batch.refresh_musicbrainz_data()

    {:noreply,
     socket
     |> put_toast(:info, gettext("Operation started in the background."))}
  end

  def handle_event("generate_record_embeddings", _params, socket) do
    Batch.generate_embeddings()

    {:noreply,
     socket
     |> put_toast(:info, gettext("Operation started in the background."))}
  end

  def handle_event("db_vacuum", _params, socket) do
    case Repo.vacuum() do
      {:ok, _result} ->
        {:noreply,
         socket
         |> put_toast(:info, gettext("Database vacuumed successfully."))}

      {:error, reason} ->
        Logger.error("Database vacuum failed: #{inspect(reason)}.")

        {:noreply,
         socket
         |> put_toast(:error, "Database vacuum failed: #{inspect(reason)}.")}
    end
  end
end
