defmodule MusicLibraryWeb.CollectionLive.Show do
  use MusicLibraryWeb, :live_view

  import MusicLibrary.ListeningStats, only: [localize_scrobbled_at: 2]

  import MusicLibraryWeb.RecordComponents,
    only: [
      record_cover: 1,
      record_debug_sheet: 1,
      record_external_links: 1,
      record_genres: 1,
      record_includes: 1,
      record_published_releases: 1,
      record_sets_list: 1,
      record_show_action_bar: 1,
      record_show_chat: 1,
      record_show_edit_modal: 1,
      record_show_release_sheet: 1,
      record_show_selected_release_row: 1,
      record_timestamps: 1,
      record_title_and_metadata: 1
    ]

  alias MusicLibrary.{ListeningStats, Records, ScrobbleActivity}
  alias MusicLibrary.Records.Similarity
  alias MusicLibraryWeb.ErrorMessages
  alias MusicLibraryWeb.LiveHelpers.RecordShow

  @common_record_events [
    "refresh_musicbrainz_data",
    "refresh_cover",
    "populate_genres",
    "extract_colors"
  ]

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_section={@current_section}
      socket={@socket}
      toasts_sync={assigns[:toasts_sync]}
    >
      <div class="mt-4 md:gap-x-4 lg:grid lg:grid-cols-2 xl:grid-cols-5">
        <div class="drop-shadow-sm xl:col-span-2">
          <.record_cover
            record={@record}
            class="w-full rounded-lg drop-shadow-sm"
          />
        </div>

        <div class="xl:col-span-3">
          <.record_show_action_bar
            record={@record}
            can_scrobble?={@can_scrobble?}
            chat_count={@chat_count}
            edit_path={~p"/collection/#{@record}/show/edit"}
          >
            <:dropdown_start>
              <.dropdown_link
                id={"actions-#{@record.id}-notes"}
                phx-click={MusicLibraryWeb.Components.Notes.open("record-notes-sheet")}
              >
                <.icon
                  name="hero-pencil"
                  class="mr-1 size-4"
                  aria-hidden="true"
                  data-slot="icon"
                />
                {gettext("Notes")}
              </.dropdown_link>
            </:dropdown_start>

            <:dropdown_extra>
              <.dropdown_link
                id={"actions-#{@record.id}-regenerate-embeddings"}
                phx-click="regenerate_embeddings"
              >
                <.icon
                  name="hero-sparkles"
                  class="phx-click-loading:animate-shake mr-1 size-4"
                  aria-hidden="true"
                  data-slot="icon"
                />
                {gettext("Regenerate embeddings")}
              </.dropdown_link>
            </:dropdown_extra>
          </.record_show_action_bar>

          <.record_title_and_metadata record={@record} />
          <.record_external_links record={@record} />
          <div class="mt-4 md:mt-8">
            <dl class="divide-y divide-zinc-100 dark:divide-slate-300/30">
              <.record_genres record={@record} section={:collection} />
              <.dl_row label={gettext("Purchased on")}>
                {Records.Record.format_as_date(@record.purchased_at)}
              </.dl_row>
              <.dl_row label={gettext("Last listened at")}>
                <span :if={@last_listened_track}>
                  {localize_scrobbled_at(@last_listened_track.scrobbled_at_uts, @timezone)}
                </span>
                <span :if={@play_count == 0}>
                  {gettext("Never")}
                </span>
                <.link
                  :if={@play_count > 0}
                  navigate={~p"/scrobbled-tracks?#{%{query: "record:#{@record.id}"}}"}
                  class="text-zinc-900 underline dark:text-zinc-100"
                >
                  {ngettext("(1 scrobble)", "(%{count} scrobbles)", @play_count)}
                </.link>
              </.dl_row>
              <.record_published_releases record={@record} />
              <.record_show_selected_release_row
                record={@record}
                label={gettext("Collected release")}
                copy_selected_release_id?={true}
              />
              <.record_includes record={@record} />
              <.record_sets_list record_sets={@record_sets} />
            </dl>
            <.record_timestamps record={@record} />
          </div>
        </div>
      </div>

      <.async_result :let={similar_records} assign={@similar_records}>
        <:loading>
          <div class="mt-8 animate-pulse">
            <div class="mb-4 h-5 w-40 rounded bg-zinc-200 dark:bg-zinc-700"></div>
            <div class="grid grid-cols-2 gap-x-4 gap-y-6 sm:grid-cols-3 sm:gap-x-6 md:grid-cols-4 lg:grid-cols-6">
              <div
                :for={_ <- 1..6}
                class="aspect-square rounded-lg bg-zinc-200 dark:bg-zinc-700"
              >
              </div>
            </div>
          </div>
        </:loading>
        <:failed :let={_failure}></:failed>
        <.similar_records similar_records={similar_records} />
      </.async_result>

      <.record_debug_sheet record={@record} embedding_text={@embedding_text} />

      <.record_show_release_sheet record={@record} show_print?={true} timezone={@timezone} />

      <.live_component
        id="record-notes"
        sheet_id="record-notes-sheet"
        module={MusicLibraryWeb.Components.Notes}
        entity={:record}
        musicbrainz_id={@record.musicbrainz_id}
      />

      <.record_show_chat record={@record} embedding_text={@embedding_text} />

      <.record_show_edit_modal
        record={@record}
        live_action={@live_action}
        show_purchased_at={true}
        close_path={~p"/collection/#{@record}"}
        patch_path={~p"/collection/#{@record}"}
      />
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:current_section, :collection)
     |> assign(:can_scrobble?, ScrobbleActivity.can_scrobble?())}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    previous_id = socket.assigns[:record] && socket.assigns.record.id

    socket =
      socket
      |> RecordShow.assign_common_record(id, gettext("Collection"))
      |> assign_collection_record_context()

    socket =
      if previous_id == id && socket.assigns[:similar_records] do
        socket
      else
        assign_similar_records(socket)
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("delete", _params, socket) do
    RecordShow.delete_record(socket, ~p"/collection")
  end

  def handle_event(event, _params, socket) when event in @common_record_events do
    RecordShow.handle_common_event(event, socket)
  end

  def handle_event("regenerate_embeddings", _params, socket) do
    record = socket.assigns.record

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
           gettext("Error") <> ": " <> ErrorMessages.friendly_message(reason)
         )}
    end
  end

  def handle_event("scrobble_release", _params, socket) do
    RecordShow.scrobble_release(socket)
  end

  @impl true
  def handle_async(:scrobble_release, result, socket) do
    RecordShow.handle_scrobble_release(result, socket)
  end

  @impl true
  def handle_info({MusicLibraryWeb.Components.RecordForm, {:saved, record}}, socket) do
    RecordShow.handle_saved_record(socket, record, &assign_similar_records/1)
  end

  def handle_info({MusicLibraryWeb.Components.Chat, :chats_changed}, socket) do
    RecordShow.handle_chats_changed(socket)
  end

  def handle_info({MusicLibraryWeb.Components.Release, {:loaded, _release}}, socket) do
    RecordShow.handle_release_loaded(socket)
  end

  def handle_info({:update, record}, socket) do
    RecordShow.handle_record_update(socket, record, &assign_similar_records/1)
  end

  attr :similar_records, :list, required: true

  defp similar_records(assigns) do
    ~H"""
    <div :if={@similar_records != []} class="mt-8">
      <header class="flex items-baseline justify-start">
        <h2 class="text-base/5 font-semibold text-zinc-700 sm:text-lg dark:text-zinc-300">
          {gettext("Similar Records")}
        </h2>
        <span class="ml-2 text-xs font-normal text-zinc-500 dark:text-zinc-400">
          {gettext("Based on genres, artists, and musical style")}
        </span>
      </header>

      <ul
        role="list"
        class="mt-4 grid grid-cols-2 gap-x-4 gap-y-6 sm:grid-cols-3 sm:gap-x-6 md:grid-cols-4 lg:grid-cols-6"
      >
        <li
          :for={%{record: record, similarity: similarity} <- @similar_records}
          class="relative cursor-pointer"
          phx-click={JS.patch(~p"/collection/#{record}")}
        >
          <div class="group">
            <.record_cover
              record={record}
              class="aspect-square rounded-lg object-cover group-hover:shadow-lg/20"
              width={300}
            />
            <span class="absolute top-2 right-2 rounded-full bg-zinc-900/75 px-2 py-0.5 text-xs font-medium text-white backdrop-blur-sm">
              {Float.round(100 - similarity * 100, 0)}%
            </span>
          </div>

          <p class="pointer-events-none mt-2 block truncate text-sm font-medium text-zinc-900 dark:text-zinc-300">
            {record.title}
          </p>
          <p class="pointer-events-none block truncate text-xs text-zinc-500 dark:text-zinc-400">
            {Records.Record.artist_names(record)}
          </p>
        </li>
      </ul>
    </div>
    """
  end

  defp assign_collection_record_context(socket) do
    record = socket.assigns.record

    socket
    |> assign(:last_listened_track, ListeningStats.get_last_listened_track(record))
    |> assign(:play_count, ListeningStats.play_count(record))
  end

  defp assign_similar_records(socket) do
    record_id = socket.assigns.record.id

    assign_async(socket, :similar_records, fn ->
      similar = Similarity.find_similar(record_id, limit: 6, scope: :collection)
      {:ok, %{similar_records: similar}}
    end)
  end
end
