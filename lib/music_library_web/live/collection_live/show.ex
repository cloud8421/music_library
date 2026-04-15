defmodule MusicLibraryWeb.CollectionLive.Show do
  use MusicLibraryWeb, :live_view

  require Logger

  import MusicLibrary.ListeningStats, only: [localize_scrobbled_at: 2]

  import MusicLibraryWeb.RecordComponents,
    only: [
      artist_links: 1,
      record_cover: 1,
      record_debug_sheet: 1,
      record_external_links: 1,
      record_genres: 1,
      record_includes: 1,
      record_published_releases: 1,
      record_sets_list: 1,
      record_timestamps: 1,
      record_title_and_metadata: 1,
      release_summary: 1
    ]

  alias MusicLibrary.{Chats, ListeningStats, Records, RecordSets, ScrobbleActivity}
  alias MusicLibrary.Records.Similarity
  alias MusicLibraryWeb.ErrorMessages
  alias MusicLibraryWeb.LiveHelpers.RecordActions
  alias Phoenix.LiveView.JS

  alias MusicBrainz

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_section={@current_section}
      socket={@socket}
      toasts_sync={assigns[:toasts_sync]}
    >
      <div class="mt-4 px-4 md:gap-x-4 lg:grid lg:grid-cols-2 xl:grid-cols-5">
        <div class="drop-shadow-sm xl:col-span-2">
          <.record_cover
            record={@record}
            class="w-full rounded-lg drop-shadow-sm"
          />
        </div>

        <div class="xl:col-span-3">
          <div class="mt-4 flex items-center justify-between md:mt-0">
            <h1 class="text-base/6 font-medium text-zinc-700">
              <.artist_links joinphrase_class="text-sm" artists={@record.artists} />
            </h1>
            <div class="min-w-12">
              <.button_group>
                <.button
                  :if={@can_scrobble? and @record.selected_release_id}
                  variant="soft"
                  phx-click="scrobble_release"
                >
                  <span class="sr-only">{gettext("Scrobble release")}</span>
                  <.icon
                    name="hero-play"
                    class="icon"
                    aria-hidden="true"
                    data-slot="icon"
                  />
                </.button>
                <.button
                  variant="soft"
                  phx-click={MusicLibraryWeb.Components.Chat.open("record-chat-sheet")}
                >
                  <span class="sr-only">{gettext("Chat about album")}</span>
                  <.icon
                    name="hero-chat-bubble-left-right"
                    class="icon"
                    aria-hidden="true"
                    data-slot="icon"
                  />
                  <span :if={@chat_count > 0} class="text-xs font-medium">{@chat_count}</span>
                </.button>
                <.button
                  :if={@record.selected_release_id}
                  variant="soft"
                  phx-click={MusicLibraryWeb.Components.Release.open("release-with-tracks-sheet")}
                >
                  <span class="sr-only">{gettext("Show Tracks")}</span>
                  <.icon
                    name="hero-numbered-list"
                    class="icon"
                    aria-hidden="true"
                    data-slot="icon"
                  />
                </.button>
                <.dropdown id={"actions-#{@record.id}"} placement="bottom-end">
                  <:toggle>
                    <.button variant="soft">
                      <span class="sr-only">{gettext("Actions")}</span>
                      <.icon
                        name="hero-ellipsis-vertical"
                        class="icon cursor-pointer text-zinc-500 dark:text-zinc-400"
                        aria-hidden="true"
                        data-slot="icon"
                      />
                    </.button>
                  </:toggle>
                  <.focus_wrap id={"actions-#{@record.id}-focus-wrap"}>
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

                    <.dropdown_link
                      id={"actions-#{@record.id}-debug"}
                      phx-click={Fluxon.open_dialog("debug-data")}
                    >
                      <.icon
                        name="hero-code-bracket"
                        class="mr-1 size-4"
                        aria-hidden="true"
                        data-slot="icon"
                      />
                      {gettext("Debug data")}
                    </.dropdown_link>

                    <.dropdown_separator />

                    <.dropdown_link
                      id={"actions-#{@record.id}-edit"}
                      patch={~p"/collection/#{@record}/show/edit"}
                    >
                      <.icon
                        name="hero-pencil-square"
                        class="phx-click-loading:animate-bounce mr-1 size-4"
                        aria-hidden="true"
                        data-slot="icon"
                      />
                      {gettext("Edit")}
                    </.dropdown_link>

                    <.dropdown_link
                      id={"actions-#{@record.id}-refresh-cover"}
                      phx-click="refresh_cover"
                    >
                      <.icon
                        name="hero-photo"
                        class="phx-click-loading:animate-bounce mr-1 size-4"
                        aria-hidden="true"
                        data-slot="icon"
                      />
                      {gettext("Refresh cover")}
                    </.dropdown_link>

                    <.dropdown_link
                      id={"actions-#{@record.id}-refresh-mb-data"}
                      phx-click="refresh_musicbrainz_data"
                    >
                      <.icon
                        name="hero-cloud-arrow-down"
                        class="phx-click-loading:animate-bounce mr-1 size-4"
                        aria-hidden="true"
                        data-slot="icon"
                      />
                      {gettext("Refresh MB data")}
                    </.dropdown_link>

                    <.dropdown_link
                      id={"actions-#{@record.id}-populate-genres"}
                      phx-click="populate_genres"
                    >
                      <.icon
                        name="hero-sparkles"
                        class="phx-click-loading:animate-shake mr-1 size-4"
                        aria-hidden="true"
                        data-slot="icon"
                      />
                      {gettext("Populate genres")}
                    </.dropdown_link>

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

                    <.dropdown_link
                      id={"actions-#{@record.id}-extract-colors"}
                      phx-click="extract_colors"
                    >
                      <.icon
                        name="hero-paint-brush"
                        class="phx-click-loading:animate-shake mr-1 size-4"
                        aria-hidden="true"
                        data-slot="icon"
                      />
                      {gettext("Extract colors")}
                    </.dropdown_link>

                    <.dropdown_separator />
                    <.dropdown_link
                      id={"actions-#{@record.id}-delete"}
                      phx-click="delete"
                      data-confirm={gettext("Are you sure?")}
                      class="text-red-900! hover:bg-red-50! dark:text-red-500! dark:hover:bg-red-900/30! dark:hover:text-red-600!"
                    >
                      <.icon
                        name="hero-trash"
                        class="phx-click-loading:animate-spin mr-1 size-4"
                        aria-hidden="true"
                        data-slot="icon"
                      />
                      {gettext("Delete")}
                    </.dropdown_link>
                  </.focus_wrap>
                </.dropdown>
              </.button_group>
            </div>
          </div>
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
              <.dl_row label={gettext("Collected release")}>
                <div class="flex justify-between space-x-2">
                  <span
                    :if={!@record.selected_release_id}
                    class="text-xs text-zinc-700 md:text-sm dark:text-zinc-300"
                  >
                    {gettext("No release selected")}
                  </span>
                  <.release_summary
                    :if={@record.selected_release_id}
                    release={Records.Record.selected_release(@record)}
                  />
                  <span
                    :if={@record.selected_release_id}
                    id={"record-selected-release-" <> @record.id}
                    class="hidden"
                  >
                    {@record.selected_release_id}
                  </span>
                  <.copy_to_clipboard
                    :if={@record.selected_release_id}
                    target_id={"record-selected-release-" <> @record.id}
                    label={gettext("Copy record selected release ID to clipboard")}
                  />
                </div>
              </.dl_row>
              <.record_includes record={@record} />
              <.record_sets_list record_sets={@record_sets} />
            </dl>
            <.record_timestamps record={@record} />
          </div>
        </div>
      </div>

      <.similar_records similar_records={@similar_records} />

      <.record_debug_sheet record={@record} embedding_text={@embedding_text} />

      <.live_component
        id="release-with-tracks"
        sheet_id="release-with-tracks-sheet"
        module={MusicLibraryWeb.Components.Release}
        record={@record}
      />

      <.live_component
        id="record-notes"
        sheet_id="record-notes-sheet"
        module={MusicLibraryWeb.Components.Notes}
        entity={:record}
        musicbrainz_id={@record.musicbrainz_id}
      />

      <.live_component
        id="record-chat"
        sheet_id="record-chat-sheet"
        module={MusicLibraryWeb.Components.Chat}
        title={@record.title}
        entity={:record}
        musicbrainz_id={@record.musicbrainz_id}
        chat_module={MusicLibrary.Chats.RecordChat}
        chat_context={{@record, @embedding_text}}
        placeholder={gettext("Ask about this album...")}
        empty_prompt={gettext("Ask anything about this album")}
      />

      <.structured_modal
        :if={@live_action == :edit}
        id="record-modal"
        on_close={JS.patch(~p"/collection/#{@record}")}
      >
        <.live_component
          module={MusicLibraryWeb.Components.RecordForm}
          id={@record.id}
          action={@live_action}
          show_purchased_at={true}
          record={@record}
          patch={~p"/collection/#{@record}"}
        />
      </.structured_modal>
    </Layouts.app>
    """
  end

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
    last_listened_track = ListeningStats.get_last_listened_track(record)
    play_count = ListeningStats.play_count(record) || 0
    record_sets = RecordSets.list_record_sets_for_record(record.id)

    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action, record))
     |> assign(:record, record)
     |> assign(:last_listened_track, last_listened_track)
     |> assign(:play_count, play_count)
     |> assign(:record_sets, record_sets)
     |> assign(:chat_count, Chats.count_chats(:record, record.musicbrainz_id))
     |> RecordActions.assign_embedding_text()
     |> assign_similar_records()}
  end

  @impl true
  def handle_event("delete", _params, socket) do
    {:ok, _} = Records.delete_record(socket.assigns.record)

    {:noreply, push_navigate(socket, to: ~p"/collection")}
  end

  def handle_event("refresh_musicbrainz_data", _params, socket) do
    RecordActions.refresh_musicbrainz_data(socket)
  end

  def handle_event("populate_genres", _params, socket) do
    RecordActions.populate_genres(socket)
  end

  def handle_event("refresh_cover", _params, socket) do
    RecordActions.refresh_cover(socket)
  end

  def handle_event("extract_colors", _params, socket) do
    RecordActions.extract_colors(socket)
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
    record = socket.assigns.record

    {:noreply,
     start_async(socket, :scrobble_release, fn ->
       with {:ok, release} <- MusicBrainz.get_release(record.selected_release_id) do
         release_with_tracks = MusicBrainz.Release.from_api_response(release)

         ScrobbleActivity.scrobble_release(release_with_tracks, :finished_at, DateTime.utc_now())
       end
     end)}
  end

  @impl true
  def handle_async(:scrobble_release, {:ok, {:ok, _result}}, socket) do
    {:noreply, put_toast(socket, :info, gettext("Release scrobbled successfully"))}
  end

  def handle_async(:scrobble_release, {:ok, {:error, reason}}, socket) do
    {:noreply,
     put_toast(
       socket,
       :error,
       gettext("Error scrobbling release") <> ": " <> ErrorMessages.friendly_message(reason)
     )}
  end

  def handle_async(:scrobble_release, {:exit, reason}, socket) do
    Logger.error("Scrobble release failed: #{inspect(reason)}")

    {:noreply,
     put_toast(
       socket,
       :error,
       gettext("Error scrobbling release") <> ": " <> ErrorMessages.friendly_message(reason)
     )}
  end

  @impl true
  def handle_info({MusicLibraryWeb.Components.RecordForm, {:saved, record}}, socket) do
    {:noreply,
     socket
     |> assign(:record, record)
     |> assign_similar_records()
     |> RecordActions.assign_embedding_text()}
  end

  def handle_info({MusicLibraryWeb.Components.Chat, :chats_changed}, socket) do
    RecordActions.handle_chats_changed(socket)
  end

  @impl true
  def handle_info({:update, record}, socket) do
    {:noreply,
     socket
     |> RecordActions.handle_record_updated(record)
     |> assign_similar_records()}
  end

  defp page_title(action, record) do
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

  defp title_segment(:show), do: gettext("Details")
  defp title_segment(:edit), do: gettext("Edit")

  attr :similar_records, :list, required: true

  defp similar_records(assigns) do
    ~H"""
    <div :if={@similar_records != []} class="mt-8 px-4">
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

  defp assign_similar_records(socket) do
    similar_records =
      Similarity.find_similar(socket.assigns.record.id, limit: 6, scope: :collection)

    assign(socket, :similar_records, similar_records)
  end
end
