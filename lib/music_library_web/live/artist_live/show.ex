defmodule MusicLibraryWeb.ArtistLive.Show do
  use MusicLibraryWeb, :live_view

  import MusicLibraryWeb.RecordComponents,
    only: [record_grid: 1, country_label: 1, artist_image: 1]

  alias MusicLibrary.{Artists, Records}
  alias MusicLibrary.Artists.ArtistInfo
  alias MusicLibraryWeb.ErrorMessages

  attr :country, :map, required: true

  defp country_flag(assigns) do
    ~H"""
    <span>{country_label(@country.code)}</span>
    <span class="sr-only">{@country.name}</span>
    """
  end

  attr :lastfm_artist_info, :map, required: true

  defp on_tour_link(assigns) do
    ~H"""
    <a
      :if={@lastfm_artist_info.on_tour}
      class="flex items-center"
      href={LastFm.Artist.events_url(@lastfm_artist_info)}
      target="_blank"
    >
      <.badge variant="soft" class="mr-2">{gettext("On Tour")}</.badge>
    </a>
    """
  end

  attr :play_count, :integer, required: true

  defp play_count(assigns) do
    ~H"""
    <span :if={@play_count > 0} class="text-xs font-medium text-zinc-700 dark:text-zinc-300 grow">
      {ngettext("1 scrobble", "%{count} scrobbles", @play_count)}
    </span>
    <span :if={@play_count == 0} class="text-xs font-medium text-zinc-700 dark:text-zinc-300 grow">
      {gettext("No scrobbles")}
    </span>
    """
  end

  attr :title, :string, required: true
  attr :artists, :list, required: true

  defp artist_grid(assigns) do
    ~H"""
    <div class="mt-4">
      <header class="flex items-baseline justify-start">
        <h2 class="font-semibold text-base sm:text-lg leading-5 text-zinc-700 dark:text-zinc-300">
          {@title}
        </h2>
      </header>
      <ul
        role="list"
        class="mt-4 grid grid-cols-3 gap-x-4 gap-y-8 sm:grid-cols-4 sm:gap-x-6 lg:grid-cols-6 xl:gap-x-8"
      >
        <li :for={artist <- @artists} class="relative">
          <div
            class="relative cursor-pointer"
            phx-click={
              JS.patch(~p"/artists/#{artist.musicbrainz_id}")
              |> JS.dispatch("music_library:scroll_top")
            }
          >
            <.artist_image
              class="aspect-square object-cover rounded-lg hover:shadow-lg/20"
              artist={artist}
              image_hash={artist.image_data_hash}
            />
          </div>
          <p class="pointer-events-none mt-2 block truncate text-sm font-medium text-zinc-900 dark:text-zinc-300">
            {artist.name}
          </p>
        </li>
      </ul>
    </div>
    """
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_section={@current_section} socket={@socket}>
      <div class="mt-4 px-4 sm:px-6 lg:px-8">
        <header class="mt-1 gap-1">
          <div class="flex items-center justify-between">
            <h1 class="font-semibold text-2xl leading-5 text-zinc-700 dark:text-zinc-300 text-wrap">
              {@artist.name}
              <.country_flag country={@country} />
            </h1>

            <div class="flex items-center">
              <.button_group>
                <.button
                  variant="soft"
                  phx-click={MusicLibraryWeb.Components.Notes.open("artist-notes-sheet")}
                >
                  <span class="sr-only">{gettext("Open Notes")}</span>
                  <.icon
                    name="hero-pencil"
                    class="h-5 w-5"
                    aria-hidden="true"
                    data-slot="icon"
                  />
                </.button>
                <.button
                  variant="soft"
                  phx-click={MusicLibraryWeb.Components.Chat.open("artist-chat-sheet")}
                >
                  <span class="sr-only">{gettext("Chat about artist")}</span>
                  <.icon
                    name="hero-chat-bubble-left-right"
                    class="h-5 w-5"
                    aria-hidden="true"
                    data-slot="icon"
                  />
                </.button>
                <.button
                  variant="soft"
                  phx-click={Fluxon.open_dialog("debug-data")}
                >
                  <span class="sr-only">{gettext("Debug data")}</span>
                  <.icon
                    name="hero-code-bracket"
                    class="h-5 w-5"
                    aria-hidden="true"
                    data-slot="icon"
                  />
                </.button>
                <.dropdown id={"actions-#{@artist.musicbrainz_id}"} placement="bottom-end">
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
                  <.focus_wrap id={"actions-#{@artist.musicbrainz_id}-focus-wrap"}>
                    <.dropdown_link
                      id={"actions-#{@artist.musicbrainz_id}-edit"}
                      patch={~p"/artists/#{@artist.musicbrainz_id}/edit"}
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
                      id={"actions-#{@artist.musicbrainz_id}-refresh-image"}
                      phx-click={
                        JS.push("refresh_artist_image", value: %{id: @artist.musicbrainz_id})
                      }
                    >
                      <.icon
                        name="hero-photo"
                        class="h-4 w-4 mr-1 phx-click-loading:animate-bounce"
                        aria-hidden="true"
                        data-slot="icon"
                      />
                      {gettext("Refresh image")}
                    </.dropdown_link>

                    <.dropdown_link
                      id={"actions-#{@artist.musicbrainz_id}-refresh-artist-info"}
                      phx-click={JS.push("refresh_artist_info", value: %{id: @artist.musicbrainz_id})}
                    >
                      <.icon
                        name="hero-arrow-path"
                        class="h-4 w-4 mr-1 phx-click-loading:animate-spin"
                        aria-hidden="true"
                        data-slot="icon"
                      />
                      {gettext("Refresh info")}
                    </.dropdown_link>
                    <.dropdown_link
                      id={"actions-#{@artist.musicbrainz_id}-refresh-wikipedia"}
                      phx-click={
                        JS.push("refresh_wikipedia_data", value: %{id: @artist.musicbrainz_id})
                      }
                    >
                      <.icon
                        name="hero-arrow-path"
                        class="h-4 w-4 mr-1 phx-click-loading:animate-spin"
                        aria-hidden="true"
                        data-slot="icon"
                      />
                      {gettext("Refresh Wikipedia")}
                    </.dropdown_link>
                    <.dropdown_link
                      id={"actions-#{@artist.musicbrainz_id}-refresh-lastfm"}
                      phx-click={JS.push("refresh_lastfm_data", value: %{id: @artist.musicbrainz_id})}
                    >
                      <.icon
                        name="hero-arrow-path"
                        class="h-4 w-4 mr-1 phx-click-loading:animate-spin"
                        aria-hidden="true"
                        data-slot="icon"
                      />
                      {gettext("Refresh Last.fm")}
                    </.dropdown_link>
                  </.focus_wrap>
                </.dropdown>
              </.button_group>
            </div>
          </div>

          <div class="mt-4 flex items-center justify-between">
            <.async_result :let={lastfm_artist_info} assign={@lastfm_artist_info}>
              <:loading>
                <span class="sr-only">{gettext("Loading play count")}</span>
                <.loading />
              </:loading>
              <:failed :let={_failure}>
                <div class="mt-4 text-sm leading-5 text-zinc-500 dark:text-zinc-400">
                  <.icon
                    name="hero-exclamation-triangle"
                    class="-mt-1 mr-1 ml-2 h-5 w-5"
                    aria-hidden="true"
                    data-slot="icon"
                  />
                  {gettext("Error loading play count")}
                </div>
              </:failed>
              <.on_tour_link lastfm_artist_info={lastfm_artist_info} />
              <.play_count play_count={lastfm_artist_info.play_count} />
            </.async_result>
          </div>
        </header>

        <div class="mt-4 grid md:grid-cols-10 md:gap-4">
          <div class="md:col-span-3 mt-4 order-2 md:order-1">
            <h2 class="font-semibold text-base sm:text-lg leading-5 text-zinc-700 dark:text-zinc-300">
              {gettext("Meta")}
            </h2>
            <.artist_image
              class="w-full rounded-md shadow-sm mt-4 cursor-pointer"
              artist={@artist}
              image_hash={@artist_info.image_data_hash}
              phx-click={Fluxon.open_dialog("artist-image-modal")}
            />
            <.modal
              id="artist-image-modal"
              class="mx-auto sm:min-w-2xl max-w-sm md:max-w-3xl lg:max-w-5xl mt-8"
              placement="center"
              open={false}
            >
              <.artist_image
                class="w-full rounded-md shadow-sm mt-8"
                artist={@artist}
                image_hash={@artist_info.image_data_hash}
              />
            </.modal>
            <div class="mt-2 flex items-center gap-2">
              <code id={"mb-#{@artist.musicbrainz_id}"} class="hidden">
                {@artist.musicbrainz_id}
              </code>
              <.button
                href={MusicBrainz.Artist.url(@artist.musicbrainz_id)}
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
                  JS.dispatch("music_library:clipcopy", to: "#mb-#{@artist.musicbrainz_id}")
                  |> JS.transition("animate-shake")
                }
              >
                <.icon name="hero-clipboard-document" class="h-3.5 w-3.5" aria-hidden="true" />
                {gettext("Copy MB ID")}
              </.button>
            </div>
            <%= if @biography do %>
              <dt class="mt-4 text-sm font-medium leading-6 text-zinc-900 dark:text-zinc-400">
                {gettext("Biography")}
                <.badge variant="soft" class="ml-1">{@biography.source}</.badge>
              </dt>
              <dd class="text-zinc-700 dark:text-zinc-300">
                <p
                  :if={@biography.description}
                  class="mt-2 text-sm italic text-zinc-500 dark:text-zinc-400"
                >
                  {@biography.description}
                </p>
                <p class="mt-2 text-sm/7">{@biography.summary_html}</p>
                <.link
                  class="block mt-2 text-sm font-medium text-zinc-900 dark:text-zinc-400"
                  phx-click={Fluxon.open_dialog("bio")}
                >
                  <.icon
                    name="hero-arrow-right-end-on-rectangle"
                    class="-mt-1 mr-1 h-5 w-5"
                    aria-hidden="true"
                    data-slot="icon"
                  />
                  {gettext("Read more")}
                </.link>
              </dd>
              <.sheet
                id="bio"
                class="max-w-2xl text-zinc-700 dark:text-zinc-300"
                placement="left"
              >
                <div class="prose prose-sm dark:prose-invert">
                  {Phoenix.HTML.raw(@biography.bio_html)}
                </div>
                <a
                  :if={@biography.url}
                  href={@biography.url}
                  target="_blank"
                  class="mt-4 block text-sm font-medium text-zinc-900 dark:text-zinc-400 hover:text-zinc-500"
                >
                  {gettext("Read full article on Wikipedia")}
                  <.icon
                    name="hero-arrow-top-right-on-square"
                    class="-mt-1 ml-1 h-4 w-4"
                    aria-hidden="true"
                    data-slot="icon"
                  />
                </a>
              </.sheet>
            <% else %>
              <.async_result :let={lastfm_artist_info} assign={@lastfm_artist_info}>
                <:loading>
                  <div class="mt-4 text-sm leading-5 text-zinc-500 dark:text-zinc-400">
                    {gettext("Loading biography")}
                  </div>
                </:loading>
                <:failed :let={_failure}>
                  <div class="mt-4 text-sm leading-5 text-zinc-500 dark:text-zinc-400">
                    <.icon
                      name="hero-exclamation-triangle"
                      class="-mt-1 mr-1 h-5 w-5"
                      aria-hidden="true"
                      data-slot="icon"
                    />
                    {gettext("Error loading biography")}
                  </div>
                </:failed>
                <dt
                  :if={lastfm_artist_info.bio not in [nil, ""]}
                  class="mt-4 text-sm font-medium leading-6 text-zinc-900 dark:text-zinc-400"
                >
                  {gettext("Biography")}
                </dt>
                <dd
                  :if={lastfm_artist_info.bio not in [nil, ""]}
                  class="text-zinc-700 dark:text-zinc-300"
                >
                  {remove_read_more_link(lastfm_artist_info.summary)}
                  <.link
                    class="block mt-2 text-sm font-medium text-zinc-900 dark:text-zinc-400"
                    phx-click={Fluxon.open_dialog("lastfm-bio")}
                  >
                    <.icon
                      name="hero-arrow-right-end-on-rectangle"
                      class="-mt-1 mr-1 h-5 w-5"
                      aria-hidden="true"
                      data-slot="icon"
                    />
                    {gettext("Read more")}
                  </.link>
                </dd>
                <.sheet
                  :if={lastfm_artist_info.bio not in [nil, ""]}
                  id="lastfm-bio"
                  class="max-w-2xl text-zinc-700 dark:text-zinc-300"
                  placement="left"
                >
                  {render_bio(lastfm_artist_info.bio)}
                </.sheet>
              </.async_result>
            <% end %>
            <.external_links external_links={@external_links} />
          </div>
          <div class="md:col-span-7 md:order-1">
            <.record_grid
              :if={@collection_records_count > 0}
              title={gettext("Collection")}
              id="collection"
              records={@streams.collection_records}
              records_count={@collection_records_count}
              record_show_path={fn record -> ~p"/collection/#{record}" end}
              record_edit_path={fn record -> ~p"/collection/#{record}/show/edit" end}
            />
            <.separator
              :if={@collection_records_count > 0 && @wishlist_records_count > 0}
              class="mt-8 mb-8"
            />
            <.record_grid
              :if={@wishlist_records_count > 0}
              title={gettext("Wishlist")}
              id="wishlist"
              records={@streams.wishlist_records}
              records_count={@wishlist_records_count}
              record_show_path={fn record -> ~p"/wishlist/#{record}" end}
              record_edit_path={fn record -> ~p"/wishlist/#{record}/show/edit" end}
            />

            <.async_result :let={similar_artists} assign={@similar_artists}>
              <:loading>
                <div class="mt-4 text-sm leading-5 text-zinc-500 dark:text-zinc-400">
                  {gettext("Loading similar artists")}
                </div>
              </:loading>
              <:failed :let={_failure}>
                <div class="mt-4 text-sm leading-5 text-zinc-500 dark:text-zinc-400">
                  <.icon
                    name="hero-exclamation-triangle"
                    class="-mt-1 mr-1 h-5 w-5"
                    aria-hidden="true"
                    data-slot="icon"
                  />
                  {gettext("Error loading similar artists")}
                </div>
              </:failed>
              <.separator class="mt-8 mb-8" />
              <.artist_grid title={gettext("Similar artists")} artists={similar_artists} />
            </.async_result>
          </div>
        </div>

        <.debug_data_sheet
          id="debug-data"
          items={
            Enum.filter(
              [
                if(@artist_info.musicbrainz_data,
                  do: %{
                    name: "musicbrainz",
                    title: gettext("MusicBrainz"),
                    data: @artist_info.musicbrainz_data,
                    type: :json
                  }
                ),
                if(@artist_info.discogs_data,
                  do: %{
                    name: "discogs",
                    title: gettext("Discogs"),
                    data: @artist_info.discogs_data,
                    type: :json
                  }
                ),
                if(@artist_info.wikipedia_data != %{},
                  do: %{
                    name: "wikipedia",
                    title: gettext("Wikipedia"),
                    data: @artist_info.wikipedia_data,
                    type: :json
                  }
                ),
                if(@artist_info.lastfm_data != %{},
                  do: %{
                    name: "lastfm",
                    title: gettext("Last.fm"),
                    data: @artist_info.lastfm_data,
                    type: :json
                  }
                )
              ],
              & &1
            )
          }
        />
      </div>

      <.live_component
        id="artist-notes"
        sheet_id="artist-notes-sheet"
        module={MusicLibraryWeb.Components.Notes}
        entity={:artist}
        musicbrainz_id={@artist.musicbrainz_id}
      />

      <.live_component
        id="artist-chat"
        sheet_id="artist-chat-sheet"
        module={MusicLibraryWeb.Components.Chat}
        title={@artist.name}
        chat_module={MusicLibrary.ArtistChat}
        chat_context={{@artist, @artist_info}}
        placeholder={gettext("Ask about this artist...")}
        empty_prompt={gettext("Ask anything about this artist")}
      />

      <.structured_modal
        :if={@live_action == :edit}
        id="artist-info-modal"
        on_close={JS.patch(~p"/artists/#{@artist.musicbrainz_id}")}
      >
        <.live_component
          module={MusicLibraryWeb.ArtistLive.Form}
          id={@artist_info.id}
          action={@live_action}
          artist_info={@artist_info}
          artist={@artist}
          patch={~p"/artists/#{@artist.musicbrainz_id}"}
        />
      </.structured_modal>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  @impl true
  def handle_event("refresh_artist_info", %{"id" => id}, socket) do
    case Artists.fetch_artist_info(id) do
      {:ok, artist_info} ->
        {:noreply,
         socket
         |> assign(:artist_info, artist_info)
         |> assign(:biography, build_biography(artist_info))
         |> put_toast(:info, gettext("Artist info refreshed successfully"))}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_toast(
           :error,
           gettext("Error refreshing artist info") <>
             ": " <> ErrorMessages.friendly_message(reason)
         )}
    end
  end

  def handle_event("refresh_wikipedia_data", %{"id" => id}, socket) do
    case Artists.refresh_wikipedia_data(id) do
      {:ok, artist_info} ->
        {:noreply,
         socket
         |> assign(:artist_info, artist_info)
         |> assign(:biography, build_biography(artist_info))
         |> put_toast(:info, gettext("Wikipedia data refreshed successfully"))}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_toast(
           :error,
           gettext("Error refreshing Wikipedia data") <>
             ": " <> ErrorMessages.friendly_message(reason)
         )}
    end
  end

  def handle_event("refresh_lastfm_data", %{"id" => id}, socket) do
    case Artists.fetch_lastfm_data(id) do
      {:ok, artist_info} ->
        id
        |> Records.get_artist_records()
        |> Enum.each(&Records.generate_embedding_async/1)

        {:noreply,
         socket
         |> assign(:artist_info, artist_info)
         |> put_toast(:info, gettext("Last.fm data refreshed successfully"))}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_toast(
           :error,
           gettext("Error refreshing Last.fm data") <>
             ": " <> ErrorMessages.friendly_message(reason)
         )}
    end
  end

  def handle_event("refresh_artist_image", %{"id" => id}, socket) do
    case Artists.fetch_image(id) do
      {:ok, artist_info} ->
        {:noreply,
         socket
         |> assign(:artist_info, artist_info)
         |> put_toast(:info, gettext("Artist image refreshed successfully"))}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_toast(
           :error,
           gettext("Error refreshing artist image") <>
             ": " <> ErrorMessages.friendly_message(reason)
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
         |> assign_records(socket.assigns.artist.musicbrainz_id)
         |> put_toast(:info, gettext("Record added to the collection"))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> put_toast(
           :error,
           gettext("Error importing record") <> ": " <> ErrorMessages.friendly_message(changeset)
         )}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    record = Records.get_record!(id)
    {:ok, _} = Records.delete_record(record)

    {:noreply,
     socket
     |> assign_records(socket.assigns.artist.musicbrainz_id)
     |> put_toast(:info, gettext("Record deleted"))}
  end

  defp apply_action(socket, :show, %{"musicbrainz_id" => musicbrainz_id}) do
    artist = Artists.get_artist!(musicbrainz_id)
    artist_info = Artists.get_artist_info!(musicbrainz_id)

    socket
    |> assign_records(musicbrainz_id)
    |> assign(:current_section, :artists)
    |> assign(:artist, artist)
    |> assign(:artist_info, artist_info)
    |> assign(:biography, build_biography(artist_info))
    |> assign(:external_links, ArtistInfo.external_links(artist_info))
    |> assign(:country, ArtistInfo.country(artist_info))
    |> assign_async(:lastfm_artist_info, fn ->
      with {:ok, lastfm_artist_info} <- LastFm.get_artist_info(artist.musicbrainz_id, artist.name) do
        {:ok, %{lastfm_artist_info: lastfm_artist_info}}
      end
    end)
    |> assign_async(:similar_artists, fn ->
      with {:ok, similar_artists} <- Artists.get_similar_artists(artist) do
        artist_image_hashes = Artists.get_image_hashes(similar_artists)

        similar_artists =
          Enum.map(similar_artists, fn artist ->
            %{artist | image_data_hash: Map.get(artist_image_hashes, artist.musicbrainz_id)}
          end)

        {:ok, %{similar_artists: similar_artists}}
      end
    end)
    |> assign(:page_title, page_title(socket.assigns.live_action, artist))
  end

  defp apply_action(socket, :edit, params) do
    socket =
      if get_in(socket.assigns, [:streams, :collection_records]) == nil do
        socket
        |> apply_action(:show, params)
      else
        socket
      end

    socket
    |> assign(:page_title, gettext("Add more · Artist"))
  end

  defp assign_records(socket, artist_musicbrainz_id) do
    %{collection: collection_records, wishlist: wishlist_records} =
      artist_musicbrainz_id
      |> Records.get_artist_records()
      |> group_and_sort()

    socket
    |> stream(:collection_records, collection_records, reset: true)
    |> stream(:wishlist_records, wishlist_records, reset: true)
    |> assign(:collection_records_count, Enum.count(collection_records))
    |> assign(:wishlist_records_count, Enum.count(wishlist_records))
  end

  defp page_title(:show, artist) do
    Enum.join(
      [
        artist.name,
        "·",
        gettext("Details")
      ],
      " "
    )
  end

  defp page_title(:edit, artist) do
    Enum.join(
      [
        artist.name,
        "·",
        gettext("Edit")
      ],
      " "
    )
  end

  defp group_and_sort(records) do
    {collection, wishlist} = Enum.split_with(records, fn r -> r.purchased_at end)

    %{
      collection: Enum.sort_by(collection, fn r -> r.release_date end, :desc),
      wishlist: Enum.sort_by(wishlist, fn r -> r.release_date end, :desc)
    }
  end

  defp build_biography(artist_info) do
    bio_html = ArtistInfo.wikipedia_bio(artist_info)

    if bio_html do
      %{
        source: "Wikipedia",
        summary_html: ArtistInfo.wikipedia_summary(artist_info),
        bio_html: bio_html,
        url: ArtistInfo.wikipedia_url(artist_info),
        description: ArtistInfo.wikipedia_description(artist_info)
      }
    end
  end

  # Bios start with text, then a link to read more on Last.fm, followed by a license text.
  # We split the bio at the read more link in order to render the license separately.
  defp render_bio(bio) do
    last_fm_link_regex = ~r/<a.*Read more on Last\.fm<\/a>\.*\s*/

    case String.split(bio, last_fm_link_regex, include_captures: true) do
      [text, link, ""] ->
        reformatted_bio =
          Enum.join(
            [
              text,
              ~s(<p class="mt-4 font-semibold text-zinc-700 hover:text-zinc-500 dark:text-zinc-300 dark:hover:text-zinc-200">#{link}</p>)
            ],
            ""
          )

        PhoenixHTMLHelpers.Format.text_to_html(reformatted_bio,
          escape: false,
          attributes: [class: "mt-2 text-sm/7"]
        )

      [text, link, license] ->
        reformatted_bio =
          Enum.join(
            [
              text,
              ~s(<p class="mt-4 font-semibold text-zinc-700 hover:text-zinc-500 dark:text-zinc-300 dark:hover:text-zinc-200">#{link}</p>),
              ~s(<p class="mt-4 italic block">#{license}</p>)
            ],
            ""
          )

        PhoenixHTMLHelpers.Format.text_to_html(reformatted_bio,
          escape: false,
          attributes: [class: "mt-2 text-sm/7"]
        )

      other ->
        PhoenixHTMLHelpers.Format.text_to_html(other,
          escape: false,
          attributes: [class: "mt-2 text-sm/7"]
        )
    end
  end

  defp remove_read_more_link(summary) do
    last_fm_link_regex = ~r/<a.*Read more on Last\.fm<\/a>\.*\s*/
    reformatted_summary = String.replace(summary, last_fm_link_regex, "")

    PhoenixHTMLHelpers.Format.text_to_html(reformatted_summary,
      escape: false,
      attributes: [class: "mt-2 text-sm/7"]
    )
  end
end
