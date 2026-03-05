defmodule MusicLibraryWeb.MaintenanceLive.Index do
  use MusicLibraryWeb, :live_view

  require Logger

  alias MusicLibrary.Artists
  alias MusicLibrary.Maintenance
  alias MusicLibrary.Records

  @poll_interval 2_000

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_section={@current_section} socket={@socket}>
      <div>
        <h1 class="mt-2 text-base lg:text-2xl text-zinc-900 dark:text-zinc-200 font-semibold">
          {gettext("Maintenance")}
        </h1>
        <h3 class="mt-4 text-base font-semibold text-zinc-900 dark:text-white">
          {gettext("Records")}
        </h3>
        <p class="mt-2 max-w-4xl text-sm text-zinc-500 dark:text-zinc-400">
          {gettext(
            "Run operations on the entire record database. Monitor execution via the Oban dashboard."
          )}
        </p>
        <ul class="mt-4">
          <li class="space-y-4">
            <.button_group>
              <.button
                type="button"
                phx-click="refresh_records_musicbrainz_data"
                disabled={@refresh_records_musicbrainz_jobs > 0}
                data-confirm={
                  gettext(
                    "Are you sure you want to refresh MusicBrainz data for all records? This operation can take a long time to complete."
                  )
                }
              >
                <.loading :if={@refresh_records_musicbrainz_jobs > 0} class="size-4" />
                {gettext("Refresh MusicBrainz data")}
              </.button>
              <.button
                type="button"
                phx-click="generate_record_embeddings"
                disabled={@generate_record_embeddings_jobs > 0}
                data-confirm={
                  gettext(
                    "Are you sure you want to regenerate embeddings for all records? This operation can take a long time to complete."
                  )
                }
              >
                <.loading :if={@generate_record_embeddings_jobs > 0} class="size-4" />
                {gettext("Regenerate record embeddings")}
              </.button>
            </.button_group>
          </li>
        </ul>
        <h3 class="mt-4 text-base font-semibold text-zinc-900 dark:text-white">
          {gettext("Artists")}
        </h3>
        <p class="mt-2 max-w-4xl text-sm text-zinc-500 dark:text-zinc-400">
          {gettext(
            "Run operations on the entire artist database. Monitor execution via the Oban dashboard."
          )}
        </p>
        <ul class="mt-4">
          <li class="space-y-4">
            <.button_group>
              <.button
                type="button"
                phx-click="refresh_artists_musicbrainz_data"
                disabled={@refresh_artists_musicbrainz_jobs > 0}
                data-confirm={
                  gettext(
                    "Are you sure you want to refresh MusicBrainz data for all artists? This operation can take a long time to complete."
                  )
                }
              >
                <.loading :if={@refresh_artists_musicbrainz_jobs > 0} class="size-4" />
                {gettext("Refresh MusicBrainz data")}
              </.button>
              <.button
                type="button"
                phx-click="refresh_artists_discogs_data"
                disabled={@refresh_artists_discogs_jobs > 0}
                data-confirm={
                  gettext(
                    "Are you sure you want to refresh Discogs data for all artists? This operation can take a long time to complete."
                  )
                }
              >
                <.loading :if={@refresh_artists_discogs_jobs > 0} class="size-4" />
                {gettext("Refresh Discogs data")}
              </.button>
              <.button
                type="button"
                phx-click="refresh_artists_wikipedia_data"
                disabled={@refresh_artists_wikipedia_jobs > 0}
                data-confirm={
                  gettext(
                    "Are you sure you want to refresh Wikipedia data for all artists? This operation can take a long time to complete."
                  )
                }
              >
                <.loading :if={@refresh_artists_wikipedia_jobs > 0} class="size-4" />
                {gettext("Refresh Wikipedia data")}
              </.button>
              <.button
                type="button"
                phx-click="refresh_artists_lastfm_data"
                disabled={@refresh_artists_lastfm_jobs > 0}
                data-confirm={
                  gettext(
                    "Are you sure you want to refresh Last.fm data for all artists? This operation can take a long time to complete."
                  )
                }
              >
                <.loading :if={@refresh_artists_lastfm_jobs > 0} class="size-4" />
                {gettext("Refresh Last.fm data")}
              </.button>
            </.button_group>
          </li>
        </ul>
        <h3 class="mt-4 text-base font-semibold text-zinc-900 dark:text-white">
          {gettext("Database")}
        </h3>
        <p class="mt-2 max-w-4xl text-sm text-zinc-500 dark:text-zinc-400">
          {gettext("Run lower-level operations on the database")}
        </p>
        <ul class="mt-4">
          <li class="space-y-4">
            <.button_group>
              <.button
                type="button"
                phx-click="db_vacuum"
                phx-disable-with={gettext("Running vacuum...")}
              >
                {gettext("Vacuum")}
              </.button>
              <.button
                type="button"
                phx-click="db_optimize"
                phx-disable-with={gettext("Running optimize...")}
              >
                {gettext("Optimize")}
              </.button>
              <.button href={~p"/backup"}>
                {gettext("Backup")}
              </.button>
            </.button_group>
          </li>
        </ul>
      </div>
    </Layouts.app>
    """
  end

  @impl true
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

  @impl true
  def handle_info(:update_job_counts, socket) do
    Process.send_after(self(), :update_job_counts, @poll_interval)

    {:noreply, assign_job_counts(socket)}
  end

  defp assign_job_counts(socket) do
    socket
    |> assign(
      :refresh_records_musicbrainz_jobs,
      Maintenance.count_active_jobs("MusicLibrary.Worker.RecordRefreshMusicBrainzData")
    )
    |> assign(
      :generate_record_embeddings_jobs,
      Maintenance.count_active_jobs("MusicLibrary.Worker.GenerateRecordEmbedding")
    )
    |> assign(
      :refresh_artists_musicbrainz_jobs,
      Maintenance.count_active_jobs("MusicLibrary.Worker.ArtistRefreshMusicBrainzData")
    )
    |> assign(
      :refresh_artists_discogs_jobs,
      Maintenance.count_active_jobs("MusicLibrary.Worker.ArtistRefreshDiscogsData")
    )
    |> assign(
      :refresh_artists_wikipedia_jobs,
      Maintenance.count_active_jobs("MusicLibrary.Worker.ArtistRefreshWikipediaData")
    )
    |> assign(
      :refresh_artists_lastfm_jobs,
      Maintenance.count_active_jobs("MusicLibrary.Worker.FetchArtistLastFmData")
    )
  end

  @impl true
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

  def handle_event("refresh_artists_wikipedia_data", _params, socket) do
    Artists.Batch.refresh_wikipedia_data()

    {:noreply,
     socket
     |> put_toast(:info, gettext("Operation started in the background."))}
  end

  def handle_event("refresh_artists_lastfm_data", _params, socket) do
    Artists.Batch.refresh_lastfm_data()

    {:noreply,
     socket
     |> put_toast(:info, gettext("Operation started in the background."))}
  end

  def handle_event("db_vacuum", _params, socket) do
    case Maintenance.vacuum() do
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
    case Maintenance.optimize() do
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
