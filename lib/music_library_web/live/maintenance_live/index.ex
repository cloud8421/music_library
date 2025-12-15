defmodule MusicLibraryWeb.MaintenanceLive.Index do
  use MusicLibraryWeb, :live_view

  import Ecto.Query

  require Logger

  alias MusicLibrary.Artists
  alias MusicLibrary.BackgroundRepo
  alias MusicLibrary.Records
  alias MusicLibrary.Repo

  @poll_interval 2_000

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Process.send_after(self(), :update_job_counts, @poll_interval)
    end

    {:ok,
     socket
     |> assign(
       page_title: gettext("Maintenance"),
       current_section: :maintenance
     )
     |> assign_job_counts()}
  end

  def handle_info(:update_job_counts, socket) do
    Process.send_after(self(), :update_job_counts, @poll_interval)

    {:noreply, assign_job_counts(socket)}
  end

  defp assign_job_counts(socket) do
    socket
    |> assign(
      :refresh_records_musicbrainz_jobs,
      count_jobs("MusicLibrary.Worker.RecordRefreshMusicBrainzData")
    )
    |> assign(
      :generate_record_embeddings_jobs,
      count_jobs("MusicLibrary.Worker.GenerateRecordEmbedding")
    )
    |> assign(
      :refresh_artists_musicbrainz_jobs,
      count_jobs("MusicLibrary.Worker.ArtistRefreshMusicBrainzData")
    )
    |> assign(
      :refresh_artists_discogs_jobs,
      count_jobs("MusicLibrary.Worker.ArtistRefreshDiscogsData")
    )
  end

  defp count_jobs(worker) do
    query =
      from j in Oban.Job,
        where: j.worker == ^worker,
        where: j.state in ["available", "scheduled", "executing", "retryable"],
        select: count(j.id)

    BackgroundRepo.one(query)
  end

  def handle_event("refresh_records_musicbrainz_data", _params, socket) do
    Records.Batch.refresh_musicbrainz_data()

    {:noreply,
     socket
     |> put_toast(:info, gettext("Operation started in the background."))}
  end

  def handle_event("generate_record_embeddings", _params, socket) do
    Records.Batch.generate_embeddings()

    {:noreply,
     socket
     |> put_toast(:info, gettext("Operation started in the background."))}
  end

  def handle_event("refresh_artists_musicbrainz_data", _params, socket) do
    Artists.Batch.refresh_musicbrainz_data()

    {:noreply,
     socket
     |> put_toast(:info, gettext("Operation started in the background."))}
  end

  def handle_event("refresh_artists_discogs_data", _params, socket) do
    Artists.Batch.refresh_discogs_data()

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

  def handle_event("db_optimize", _params, socket) do
    case Repo.optimize() do
      {:ok, _result} ->
        {:noreply,
         socket
         |> put_toast(:info, gettext("Database optimized successfully."))}

      {:error, reason} ->
        Logger.error("Database optimize failed: #{inspect(reason)}.")

        {:noreply,
         socket
         |> put_toast(:error, "Database optimize failed: #{inspect(reason)}.")}
    end
  end
end
