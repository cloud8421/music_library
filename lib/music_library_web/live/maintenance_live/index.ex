defmodule MusicLibraryWeb.MaintenanceLive.Index do
  use MusicLibraryWeb, :live_view

  require Logger

  alias MusicLibrary.Artists
  alias MusicLibrary.Assets.Cache
  alias MusicLibrary.Maintenance
  alias MusicLibrary.Records
  alias MusicLibrary.Secrets
  alias MusicLibrary.Worker.PruneAssets
  alias MusicLibraryWeb.ErrorMessages
  alias MusicLibraryWeb.RecordsOnThisDayEmail

  @poll_interval 2_000

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_section={@current_section}
      socket={@socket}
      toasts_sync={assigns[:toasts_sync]}
    >
      <div>
        <h3 class="mt-2 text-base font-semibold text-zinc-900 dark:text-zinc-200">
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
        <h3 class="mt-4 text-base font-semibold text-zinc-900 dark:text-zinc-200">
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
        <h3 class="mt-4 text-base font-semibold text-zinc-900 dark:text-zinc-200">
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
        <h3 class="mt-4 text-base font-semibold text-zinc-900 dark:text-zinc-200">
          {gettext("Assets")}
        </h3>
        <p class="mt-2 max-w-4xl text-sm text-zinc-500 dark:text-zinc-400">
          {gettext("Manage cached and stored assets.")}
        </p>
        <ul class="mt-4">
          <li class="space-y-4">
            <.button_group>
              <.button
                type="button"
                phx-click="prune_asset_cache"
                phx-disable-with={gettext("Pruning...")}
              >
                {gettext("Prune asset cache")}
              </.button>
              <.button
                type="button"
                phx-click="prune_assets"
                phx-disable-with={gettext("Pruning...")}
                data-confirm={
                  gettext(
                    "Are you sure you want to prune unreferenced assets? This will permanently delete data."
                  )
                }
              >
                {gettext("Prune unreferenced assets")}
              </.button>
            </.button_group>
          </li>
        </ul>
        <h3 class="mt-4 text-base font-semibold text-zinc-900 dark:text-zinc-200">
          {gettext("Emails")}
        </h3>
        <p class="mt-2 max-w-4xl text-sm text-zinc-500 dark:text-zinc-400">
          {gettext("Manually trigger email notifications.")}
        </p>
        <ul class="mt-4">
          <li class="space-y-4">
            <.button_group>
              <.button
                type="button"
                phx-click="send_records_on_this_day_email"
                phx-disable-with={gettext("Sending...")}
              >
                {gettext("Send records on this day")}
              </.button>
            </.button_group>
          </li>
        </ul>
        <h3 class="mt-4 text-base font-semibold text-zinc-900 dark:text-zinc-200">
          {gettext("Last.fm")}
        </h3>
        <p class="mt-2 max-w-4xl text-sm text-zinc-500 dark:text-zinc-400">
          {gettext("Manage your Last.fm connection.")}
          <.async_result :let={status} assign={@lastfm_status}>
            <:loading>
              <span class="ml-2 inline-flex items-center rounded-full bg-zinc-100 px-2 py-0.5 text-xs font-medium text-zinc-600 dark:bg-zinc-700 dark:text-zinc-300">
                {gettext("Checking...")}
              </span>
            </:loading>
            <:failed :let={_failure}>
              <span class="ml-2 inline-flex items-center rounded-full bg-red-100 px-2 py-0.5 text-xs font-medium text-red-800 dark:bg-red-900 dark:text-red-200">
                {gettext("Not connected")}
              </span>
            </:failed>
            <span
              :if={status == :not_connected}
              class="ml-2 inline-flex items-center rounded-full bg-red-100 px-2 py-0.5 text-xs font-medium text-red-800 dark:bg-red-900 dark:text-red-200"
            >
              {gettext("Not connected")}
            </span>
            <span
              :if={status == :outdated_token}
              class="ml-2 inline-flex items-center rounded-full bg-yellow-100 px-2 py-0.5 text-xs font-medium text-yellow-800 dark:bg-yellow-900 dark:text-yellow-200"
            >
              {gettext("Outdated token")}
            </span>
            <span
              :if={is_tuple(status) and elem(status, 0) == :connected}
              class="ml-2 inline-flex items-center rounded-full bg-green-100 px-2 py-0.5 text-xs font-medium text-green-800 dark:bg-green-900 dark:text-green-200"
            >
              {gettext("Connected as %{username}", username: elem(status, 1))}
            </span>
          </.async_result>
        </p>
        <ul class="mt-4">
          <li class="space-y-4">
            <.button_group>
              <.button
                type="button"
                phx-click="reconnect_lastfm"
                data-confirm={
                  gettext(
                    "Are you sure you want to re-connect to Last.fm? This will disconnect the current account."
                  )
                }
              >
                {gettext("Re-connect to Last.fm")}
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
     |> assign_job_counts()
     |> assign_async(:lastfm_status, fn ->
       status =
         case Secrets.get("last_fm_session_key") do
           nil ->
             :not_connected

           %{value: value} ->
             case LastFm.get_profile(value) do
               {:ok, username} -> {:connected, username}
               {:error, _} -> :outdated_token
             end
         end

       {:ok, %{lastfm_status: status}}
     end)}
  end

  @impl true
  def handle_info(:update_job_counts, socket) do
    Process.send_after(self(), :update_job_counts, @poll_interval)

    {:noreply, assign_job_counts(socket)}
  end

  defp assign_job_counts(socket) do
    counts = Maintenance.count_active_jobs_by_worker()

    socket
    |> assign(
      :refresh_records_musicbrainz_jobs,
      Map.get(counts, "MusicLibrary.Worker.RecordRefreshMusicBrainzData", 0)
    )
    |> assign(
      :generate_record_embeddings_jobs,
      Map.get(counts, "MusicLibrary.Worker.GenerateRecordEmbedding", 0)
    )
    |> assign(
      :refresh_artists_musicbrainz_jobs,
      Map.get(counts, "MusicLibrary.Worker.ArtistRefreshMusicBrainzData", 0)
    )
    |> assign(
      :refresh_artists_discogs_jobs,
      Map.get(counts, "MusicLibrary.Worker.ArtistRefreshDiscogsData", 0)
    )
    |> assign(
      :refresh_artists_wikipedia_jobs,
      Map.get(counts, "MusicLibrary.Worker.ArtistRefreshWikipediaData", 0)
    )
    |> assign(
      :refresh_artists_lastfm_jobs,
      Map.get(counts, "MusicLibrary.Worker.FetchArtistLastFmData", 0)
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

  def handle_event("prune_asset_cache", _params, socket) do
    prune_count = Cache.prune()

    {:noreply,
     put_toast(socket, :info, gettext("Pruned %{count} cached assets.", count: prune_count))}
  end

  def handle_event("prune_assets", _params, socket) do
    %{} |> PruneAssets.new() |> Oban.insert()

    {:noreply, put_toast(socket, :info, gettext("Asset pruning started in the background."))}
  end

  def handle_event("send_records_on_this_day_email", _params, socket) do
    today = DateTime.now!(MusicLibrary.default_timezone()) |> DateTime.to_date()

    socket =
      case RecordsOnThisDayEmail.send(today) do
        {:ok, :sent} ->
          put_toast(socket, :info, gettext("Email sent successfully."))

        {:ok, :no_records} ->
          put_toast(socket, :info, gettext("No records on this day."))

        {:error, reason} ->
          Logger.error("Failed to send records on this day email: #{inspect(reason)}.")

          put_toast(
            socket,
            :error,
            gettext("Failed to send email") <> ": " <> ErrorMessages.friendly_message(reason)
          )
      end

    {:noreply, socket}
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
         |> put_toast(
           :error,
           gettext("Database vacuum failed") <> ": " <> ErrorMessages.friendly_message(reason)
         )}
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
         |> put_toast(
           :error,
           gettext("Database optimize failed") <> ": " <> ErrorMessages.friendly_message(reason)
         )}
    end
  end

  def handle_event("reconnect_lastfm", _params, socket) do
    Secrets.delete("last_fm_session_key")

    {:noreply, redirect(socket, external: LastFm.auth_url())}
  end
end
