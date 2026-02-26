defmodule MusicLibraryWeb.WishlistLive.Show do
  use MusicLibraryWeb, :live_view

  import MusicLibraryWeb.RecordComponents,
    only: [
      format_label: 1,
      type_label: 1,
      release_summary: 1,
      artist_links: 1,
      record_colors: 1,
      record_cover: 1,
      release_list: 1
    ]

  alias MusicLibrary.OnlineStoreTemplates
  alias MusicLibrary.{Records, RecordSets}
  alias MusicLibrary.Records.Similarity
  alias MusicLibrary.RecordSets.RecordSet

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_section={@current_section} socket={@socket}>
      <div class="md:flex mt-4 px-4 md:gap-x-4">
        <div class="drop-shadow-sm md:max-w-152 lg:min-w-152">
          <.record_cover
            record={@record}
            class="w-full rounded-lg drop-shadow-sm"
          />
        </div>

        <div class="grow">
          <div class="mt-4 md:mt-0 flex justify-between items-center">
            <h1 class="text-base font-medium leading-6 text-zinc-700">
              <.artist_links joinphrase_class="text-sm" artists={@record.artists} />
            </h1>
            <div class="min-w-12">
              <.button_group>
                <.button
                  variant="soft"
                  phx-click={MusicLibraryWeb.Components.Chat.open("record-chat-sheet")}
                >
                  <span class="sr-only">{gettext("Chat about album")}</span>
                  <.icon
                    name="hero-chat-bubble-left-right"
                    class="h-5 w-5"
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
                        class="h-5 w-5 text-zinc-500 dark:text-zinc-400 cursor-pointer"
                        aria-hidden="true"
                        data-slot="icon"
                      />
                    </.button>
                  </:toggle>
                  <.focus_wrap id={"actions-#{@record.id}-focus-wrap"}>
                    <.dropdown_link
                      id={"actions-#{@record.id}-edit"}
                      patch={~p"/wishlist/#{@record}/show/edit"}
                    >
                      <.icon
                        name="hero-pencil-square"
                        class="h-4 w-4 mr-1 phx-click-loading:animate-bounce"
                        aria-hidden="true"
                        data-slot="icon"
                      />
                      {gettext("Edit")}
                    </.dropdown_link>

                    <.dropdown_link
                      id={"actions-#{@record.id}-refresh-cover"}
                      phx-click={JS.push("refresh_cover", value: %{id: @record.id})}
                    >
                      <.icon
                        name="hero-photo"
                        class="h-4 w-4 mr-1 phx-click-loading:animate-bounce"
                        aria-hidden="true"
                        data-slot="icon"
                      />
                      {gettext("Refresh cover")}
                    </.dropdown_link>

                    <.dropdown_link
                      id={"actions-#{@record.id}-refresh-mb-data"}
                      phx-click={JS.push("refresh_musicbrainz_data", value: %{id: @record.id})}
                    >
                      <.icon
                        name="hero-arrow-path"
                        class="h-4 w-4 mr-1 phx-click-loading:animate-spin"
                        aria-hidden="true"
                        data-slot="icon"
                      />
                      {gettext("Refresh MB data")}
                    </.dropdown_link>

                    <.dropdown_link
                      id={"actions-#{@record.id}-populate-genres"}
                      phx-click={JS.push("populate_genres", value: %{id: @record.id})}
                    >
                      <.icon
                        name="hero-sparkles"
                        class="h-4 w-4 mr-1 phx-click-loading:animate-shake"
                        aria-hidden="true"
                        data-slot="icon"
                      />
                      {gettext("Populate genres")}
                    </.dropdown_link>

                    <.dropdown_link
                      :if={!@record.purchased_at}
                      id={"actions-#{@record.id}-purchase"}
                      phx-click={
                        JS.dispatch("music_library:confetti")
                        |> JS.push("add-to-collection", value: %{id: @record.id})
                      }
                    >
                      <.icon
                        name="hero-banknotes"
                        class="h-4 w-4 mr-1 phx-click-loading:animate-shake"
                        aria-hidden="true"
                        data-slot="icon"
                      />
                      {gettext("Purchased")}
                    </.dropdown_link>

                    <.dropdown_link
                      id={"actions-#{@record.id}-extract-colors-fast"}
                      phx-click={JS.push("extract_colors", value: %{id: @record.id, method: :fast})}
                    >
                      <.icon
                        name="hero-paint-brush"
                        class="h-4 w-4 mr-1 phx-click-loading:animate-shake"
                        aria-hidden="true"
                        data-slot="icon"
                      />
                      {gettext("Extract colors (fast)")}
                    </.dropdown_link>

                    <.dropdown_link
                      id={"actions-#{@record.id}-extract-colors-slow"}
                      phx-click={JS.push("extract_colors", value: %{id: @record.id, method: :slow})}
                    >
                      <.icon
                        name="hero-paint-brush"
                        class="h-4 w-4 mr-1 phx-click-loading:animate-shake"
                        aria-hidden="true"
                        data-slot="icon"
                      />
                      {gettext("Extract colors (slow)")}
                    </.dropdown_link>

                    <.dropdown_separator />
                    <.dropdown_link
                      id={"actions-#{@record.id}-delete"}
                      phx-click={JS.push("delete", value: %{id: @record.id})}
                      data-confirm={gettext("Are you sure?")}
                      class="text-red-900! hover:bg-red-50! dark:text-red-500! dark:hover:bg-red-900/30! dark:hover:text-red-600!"
                    >
                      <.icon
                        name="hero-trash"
                        class="h-4 w-4 mr-1 phx-click-loading:animate-spin"
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
          <div>
            <h2 class="mt-1 flex font-semibold text-lg md:text-2xl text-zinc-700 dark:text-zinc-300 text-wrap">
              {@record.title}
            </h2>
            <p class="flex items-center mt-2 text-sm text-zinc-500 dark:text-zinc-400">
              <.record_colors record={@record} />

              <span class="ml-1">
                <.icon
                  name="hero-calendar-days"
                  class="-mt-1 h-4 w-4"
                  aria-hidden="true"
                  data-slot="icon"
                />
                {Records.Record.format_release_date(@record.release_date)}
                <span :if={@current_date && !Records.Record.released?(@record, @current_date)}>
                  ({gettext("Unreleased")})
                </span>
                · {format_label(@record.format)} · {type_label(@record.type)}
              </span>
            </p>
          </div>
          <div class="mt-2 flex items-center gap-2">
            <code id={"record-#{@record.id}"} class="hidden">{@record.id}</code>
            <code id={"mb-#{@record.musicbrainz_id}"} class="hidden">
              {@record.musicbrainz_id}
            </code>
            <.button
              href={MusicBrainz.ReleaseGroup.url(@record.musicbrainz_id)}
              target="_blank"
              rel="noopener noreferrer"
              variant="ghost"
              size="xs"
            >
              <.icon name="hero-arrow-top-right-on-square" class="h-3.5 w-3.5" aria-hidden="true" />
              {gettext("MusicBrainz")}
            </.button>
            <.button
              variant="ghost"
              size="xs"
              phx-click={
                JS.dispatch("music_library:clipcopy", to: "#record-#{@record.id}")
                |> JS.transition("animate-shake")
              }
            >
              <.icon name="hero-clipboard-document" class="h-3.5 w-3.5" aria-hidden="true" />
              {gettext("Copy ID")}
            </.button>
            <.button
              variant="ghost"
              size="xs"
              phx-click={
                JS.dispatch("music_library:clipcopy", to: "#mb-#{@record.musicbrainz_id}")
                |> JS.transition("animate-shake")
              }
            >
              <.icon name="hero-clipboard-document" class="h-3.5 w-3.5" aria-hidden="true" />
              {gettext("Copy MB ID")}
            </.button>
          </div>
          <div class="mt-4 md:mt-8">
            <dl class="divide-y divide-zinc-100 dark:divide-slate-300/30">
              <.dl_row label={gettext("Genres")}>
                <.link
                  :for={genre <- @record.genres}
                  patch={~p"/wishlist?#{%{query: ~s(genre:"#{genre}")}}"}
                >
                  <.badge variant="soft">
                    {genre}
                  </.badge>
                </.link>
              </.dl_row>
              <.dl_row label={gettext("Published releases")}>
                <div class="flex justify-between">
                  {Records.Record.release_count(@record)}
                  <.release_list record={@record} />
                  <button phx-click={Fluxon.open_dialog("release-list-" <> @record.id)}>
                    <span class="sr-only">
                      {gettext("Show releases included in the record")}
                    </span>
                    <.icon
                      name="hero-magnifying-glass-plus"
                      class="-mt-1 h-5 w-5"
                      aria-hidden="true"
                      data-slot="icon"
                    />
                  </button>
                </div>
              </.dl_row>
              <.dl_row label={gettext("Wishlisted release")}>
                <div class="flex justify-between space-x-2">
                  <span
                    :if={!@record.selected_release_id}
                    class="text-xs md:text-sm text-zinc-700 dark:text-zinc-300"
                  >
                    {gettext("No release selected")}
                  </span>
                  <.release_summary
                    :if={@record.selected_release_id}
                    release={Records.Record.selected_release(@record)}
                  />
                </div>
              </.dl_row>
              <.dl_row
                :if={Records.Record.included_release_groups_count(@record) > 0}
                label={gettext("Includes")}
              >
                <ul>
                  <li :for={included_release_group <- Records.Record.included_release_groups(@record)}>
                    {included_release_group.artists} - {included_release_group.title}
                  </li>
                </ul>
              </.dl_row>
              <.dl_row :if={@record_sets != []} label={gettext("Record sets")}>
                <ul>
                  <li :for={record_set <- @record_sets} class="flex items-baseline gap-2">
                    <.link
                      navigate={~p"/record-sets/#{record_set}"}
                      class="text-zinc-700 hover:text-zinc-500 dark:text-zinc-400 dark:hover:text-zinc-300 hover:underline"
                    >
                      {record_set.name}
                    </.link>
                    <span class="text-xs text-zinc-500 dark:text-zinc-400">
                      {gettext(
                        "%{collected}/%{total} collected",
                        RecordSet.count_by_status(record_set)
                      )}
                    </span>
                  </li>
                </ul>
              </.dl_row>
            </dl>
            <p class="mt-2 flex items-center gap-1.5 text-xs text-zinc-400 dark:text-zinc-500">
              <.icon name="hero-clock" class="h-3.5 w-3.5" aria-hidden="true" />
              {gettext("Added %{date}", date: Records.Record.format_as_date(@record.inserted_at))}
              <span>·</span>
              {gettext("Updated %{date}", date: Records.Record.format_as_date(@record.updated_at))}
            </p>
          </div>
        </div>
      </div>

      <div :if={@online_store_templates != []} class="mt-4">
        <details class="px-4 text-zinc-700 hover:text-zinc-500 dark:text-zinc-400 dark:hover:text-zinc-300">
          <summary class="text-xs sm:text-sm font-medium cursor-pointer">
            {gettext("Check Online Stores")}
          </summary>
          <div class="mt-4 space-y-2">
            <.button
              :for={template <- @online_store_templates}
              href={OnlineStoreTemplates.generate_url(template, @record)}
              target="_blank"
              rel="noopener noreferrer"
              variant="ghost"
              size="sm"
              class="ml-2"
            >
              <img
                class="mr-2"
                src={favicon_url(template.url_template)}
                alt={template.name}
                loading="lazy"
              />
              <span class="text-sm font-medium text-zinc-900 dark:text-white">
                {template.name}
              </span>
            </.button>
          </div>
        </details>
      </div>

      <.json_viewer title={gettext("MusicBrainz data")} data={@record.musicbrainz_data} />
      <.text_viewer title={gettext("Record Embedding")} data={@embedding_text} />

      <.live_component
        id="record-chat"
        sheet_id="record-chat-sheet"
        module={MusicLibraryWeb.Components.Chat}
        title={@record.title}
        chat_module={MusicLibrary.RecordChat}
        chat_context={{@record, @embedding_text}}
        placeholder={gettext("Ask about this album...")}
        empty_prompt={gettext("Ask anything about this album")}
      />

      <.structured_modal
        :if={@live_action == :edit}
        id="record-modal"
        on_close={JS.patch(~p"/wishlist/#{@record}")}
      >
        <.live_component
          module={MusicLibraryWeb.Components.RecordForm}
          id={@record.id}
          action={@live_action}
          show_purchased_at={false}
          record={@record}
          patch={~p"/wishlist/#{@record}"}
        />
      </.structured_modal>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => record_id}, _session, socket) do
    current_date = DateTime.utc_now() |> DateTime.to_date()

    if connected?(socket) do
      Records.subscribe(record_id)
    end

    {:ok,
     socket
     |> assign(current_section: :wishlist)
     |> assign(:current_date, current_date)}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    record = Records.get_record!(id)
    online_store_templates = OnlineStoreTemplates.list_enabled_templates()

    record_sets = RecordSets.list_record_sets_for_record(record.id)

    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action, record))
     |> assign(:record, record)
     |> assign(:online_store_templates, online_store_templates)
     |> assign(:record_sets, record_sets)
     |> assign_embedding_text()}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    record = Records.get_record!(id)
    {:ok, _} = Records.delete_record(record)

    {:noreply, push_navigate(socket, to: ~p"/wishlist")}
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

  def handle_event("refresh_cover", %{"id" => id}, socket) do
    record = Records.get_record!(id)

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
           gettext("Error refreshing Cover") <> "," <> inspect(reason)
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

  def handle_event("add-to-collection", %{"id" => id}, socket) do
    record = Records.get_record!(id)
    current_time = DateTime.utc_now()

    case Records.update_record(record, %{"purchased_at" => current_time}) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_toast(:info, gettext("Record added to the collection"))
         |> push_navigate(to: ~p"/wishlist")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
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

  @impl true
  def handle_info({MusicLibraryWeb.Components.RecordForm, {:saved, record}}, socket) do
    {:noreply,
     socket
     |> assign(:record, record)
     |> assign_embedding_text()}
  end

  @impl true
  def handle_info({:update, record}, socket) do
    {:noreply,
     socket
     |> put_toast(:info, gettext("Record updated in the background"))
     |> assign(:record, record)
     |> assign_embedding_text()}
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
        gettext("Wishlist")
      ],
      " "
    )
  end

  defp assign_embedding_text(socket) do
    case Similarity.get_embedding_text(socket.assigns.record.id) do
      {:ok, text} -> assign(socket, :embedding_text, text)
      {:error, _reason} -> assign(socket, :embedding_text, gettext("Not available"))
    end
  end

  defp title_segment(:show), do: gettext("Show")
  defp title_segment(:edit), do: gettext("Edit")
end
