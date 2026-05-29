defmodule MusicLibraryWeb.WishlistLive.Show do
  use MusicLibraryWeb, :live_view

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

  alias MusicLibrary.OnlineStoreTemplates
  alias MusicLibrary.{Records, ScrobbleActivity}
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
            edit_path={~p"/wishlist/#{@record}/show/edit"}
          >
            <:dropdown_extra>
              <.dropdown_link
                :if={!@record.purchased_at}
                id={"actions-#{@record.id}-purchase"}
                phx-click={
                  JS.dispatch("music_library:confetti")
                  |> JS.push("add-to-collection")
                }
              >
                <.icon
                  name="hero-banknotes"
                  class="phx-click-loading:animate-shake mr-1 size-4"
                  aria-hidden="true"
                  data-slot="icon"
                />
                {gettext("Purchased")}
              </.dropdown_link>
            </:dropdown_extra>
          </.record_show_action_bar>

          <.record_title_and_metadata record={@record} current_date={@current_date} />
          <.record_external_links record={@record} />
          <div class="mt-4 md:mt-8">
            <dl class="divide-y divide-zinc-100 dark:divide-slate-300/30">
              <.record_genres record={@record} section={:wishlist} />
              <.record_published_releases record={@record} />
              <.record_show_selected_release_row
                record={@record}
                label={gettext("Wishlisted release")}
              />
              <.record_includes record={@record} />
              <.record_sets_list record_sets={@record_sets} />
            </dl>
            <.record_timestamps record={@record} />
          </div>
        </div>
      </div>

      <div :if={@online_store_templates != []} class="mt-4">
        <details class="px-4 text-zinc-700 hover:text-zinc-500 dark:text-zinc-400 dark:hover:text-zinc-300">
          <summary class="cursor-pointer text-xs font-medium sm:text-sm">
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
              <.icon
                name="hero-arrow-top-right-on-square"
                class="size-3.5 text-zinc-400"
                aria-hidden="true"
              />
            </.button>
          </div>
        </details>
      </div>

      <.record_debug_sheet record={@record} embedding_text={@embedding_text} />

      <.record_show_release_sheet record={@record} show_print?={false} timezone={@timezone} />

      <.record_show_chat record={@record} embedding_text={@embedding_text} />

      <.record_show_edit_modal
        record={@record}
        live_action={@live_action}
        show_purchased_at={false}
        close_path={~p"/wishlist/#{@record}"}
        patch_path={~p"/wishlist/#{@record}"}
      />
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    current_date = DateTime.utc_now() |> DateTime.to_date()

    {:ok,
     socket
     |> assign(current_section: :wishlist)
     |> assign(:can_scrobble?, ScrobbleActivity.can_scrobble?())
     |> assign(:current_date, current_date)}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    {:noreply,
     socket
     |> RecordShow.assign_common_record(id, gettext("Wishlist"))
     |> assign(:online_store_templates, OnlineStoreTemplates.list_enabled_templates())}
  end

  @impl true
  def handle_event("delete", _params, socket) do
    RecordShow.delete_record(socket, ~p"/wishlist")
  end

  def handle_event(event, _params, socket) when event in @common_record_events do
    RecordShow.handle_common_event(event, socket)
  end

  def handle_event("add-to-collection", _params, socket) do
    record = socket.assigns.record
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

  def handle_event("scrobble_release", _params, socket) do
    RecordShow.scrobble_release(socket)
  end

  @impl true
  def handle_async(:scrobble_release, result, socket) do
    RecordShow.handle_scrobble_release(result, socket)
  end

  @impl true
  def handle_info({MusicLibraryWeb.Components.RecordForm, {:saved, record}}, socket) do
    RecordShow.handle_saved_record(socket, record)
  end

  def handle_info({MusicLibraryWeb.Components.Chat, :chats_changed}, socket) do
    RecordShow.handle_chats_changed(socket)
  end

  def handle_info({MusicLibraryWeb.Components.Release, {:loaded, _release}}, socket) do
    RecordShow.handle_release_loaded(socket)
  end

  def handle_info({:update, record}, socket) do
    RecordShow.handle_record_update(socket, record)
  end
end
