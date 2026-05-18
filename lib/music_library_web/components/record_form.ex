defmodule MusicLibraryWeb.Components.RecordForm do
  use MusicLibraryWeb, :live_component

  import MusicLibraryWeb.RecordComponents,
    only: [format_label: 1, type_label: 1, release_label: 1, release_summary: 1, record_cover: 1]

  alias MusicLibrary.{Assets, Records}
  alias MusicLibrary.Assets.Image
  alias MusicLibrary.Records.Record
  alias MusicLibraryWeb.ErrorMessages

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> allow_upload(:cover_data, accept: ~w(.jpg .jpeg .png .webp), max_entries: 1)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="w-full">
      <header>
        <h1 class="text-base/6 font-medium text-zinc-700 dark:text-zinc-300">
          {Record.artist_names(@record)}
        </h1>
        <h2 class="mt-1 flex text-lg/5 font-semibold text-wrap text-zinc-700 md:text-2xl dark:text-zinc-300">
          {@record.title}
        </h2>
      </header>

      <.simple_form
        for={@form}
        id="record-form"
        phx-target={@myself}
        phx-change="validate"
        phx-auto-recover="recover_form"
        phx-submit="save"
      >
        <.input field={@form[:title]} label={gettext("Title")} />
        <div class="space-y-2 sm:columns-2">
          <.select field={@form[:type]} label={gettext("Type")} options={types_with_labels()} />
          <.select field={@form[:format]} label={gettext("Format")} options={formats_with_labels()} />
        </div>
        <.input class="font-mono" field={@form[:musicbrainz_id]} label={gettext("MusicBrainz ID")} />
        <.select
          field={@form[:selected_release_id]}
          label={gettext("Selected Release")}
          options={selected_release_id_options(@record)}
        >
          <:option :let={{_label, value}}>
            <.release_option release={Records.Record.find_release(@record, value)} />
          </:option>
        </.select>
        <div class={[@show_purchased_at && "sm:columns-2", "space-y-2"]}>
          <.input
            field={@form[:release_date]}
            label={gettext("Release Date")}
            sublabel={gettext("ISO format")}
          />
          <.date_time_picker
            :if={@show_purchased_at}
            field={@form[:purchased_at]}
            display_format="%B %-d, %Y at %I:%M %p"
            navigation="extended"
            label={gettext("Purchased at")}
          />
        </div>
        <div class="space-y-2">
          <.label>{gettext("Genres")}</.label>
          <input type="hidden" name="record[genres][]" value="" />
          <input
            :for={genre <- get_current_genres(assigns)}
            type="hidden"
            name="record[genres][]"
            value={genre}
          />
          <div class="flex flex-wrap gap-2">
            <.badge
              :for={genre <- get_current_genres(assigns)}
              variant="soft"
              phx-click="remove_genre"
              phx-value-genre={genre}
              phx-target={@myself}
              class="cursor-pointer"
            >
              {genre}
              <.icon name="hero-x-mark" class="size-3.5" />
            </.badge>
          </div>
          <div class="relative" id="genre-input-container" phx-hook=".GenreInput" phx-target={@myself}>
            <.input
              type="text"
              id="genre-input"
              name="genre-input"
              value={@genre_query}
              autocomplete="off"
              placeholder={gettext("Search or add genres...")}
            />
            <ul
              :if={
                @genre_suggestions != [] or
                  (@genre_query != "" and @genre_query not in get_current_genres(assigns))
              }
              role="listbox"
              id="genre-suggestions"
              class={[
                "absolute z-10 mt-1 max-h-60 w-full overflow-auto rounded-md",
                "bg-white dark:bg-zinc-800",
                "py-1 shadow-lg",
                "ring-1 ring-black/5 dark:ring-white/10"
              ]}
            >
              <li
                :for={suggestion <- @genre_suggestions}
                phx-click="add_genre"
                phx-value-genre={suggestion}
                phx-target={@myself}
                class={[
                  "cursor-pointer px-3 py-2 text-sm select-none",
                  "text-zinc-700 dark:text-zinc-300",
                  "hover:bg-zinc-100 dark:hover:bg-zinc-700",
                  "aria-selected:bg-zinc-100 dark:aria-selected:bg-zinc-700"
                ]}
                role="option"
              >
                {suggestion}
              </li>
              <li
                :if={
                  @genre_query != "" and
                    String.downcase(String.trim(@genre_query)) not in Enum.map(
                      @genre_suggestions,
                      &String.downcase/1
                    ) and String.trim(@genre_query) != ""
                }
                phx-click="add_genre"
                phx-value-genre={String.downcase(String.trim(@genre_query))}
                phx-target={@myself}
                class={[
                  "cursor-pointer px-3 py-2 text-sm select-none",
                  "text-zinc-500 italic dark:text-zinc-400",
                  "hover:bg-zinc-100 dark:hover:bg-zinc-700",
                  "aria-selected:bg-zinc-100 dark:aria-selected:bg-zinc-700"
                ]}
                role="option"
              >
                {gettext("Create \"%{genre}\"", genre: String.downcase(String.trim(@genre_query)))}
              </li>
            </ul>
          </div>
          <script :type={Phoenix.LiveView.ColocatedHook} name=".GenreInput">
            export default {
              mounted() {
                this.input = this.el.querySelector("#genre-input");
                this.selectedIndex = -1;
                this.debounceTimer = null;

                this.input.addEventListener("input", (e) => {
                  clearTimeout(this.debounceTimer);
                  this.debounceTimer = setTimeout(() => {
                    this.pushEventTo(this.el, "search_genres", { value: e.target.value });
                  }, 150);
                });

                this.input.addEventListener("keydown", (e) => {
                  const list = this.el.querySelector("#genre-suggestions");
                  if (!list) {
                    if (e.key === "Enter") {
                      e.preventDefault();
                      const value = this.input.value.trim().toLowerCase();
                      if (value) {
                        this.pushEventTo(this.el, "add_genre", { genre: value });
                        this.input.value = "";
                      }
                    }
                    return;
                  }

                  const items = list.querySelectorAll("[role='option']");
                  if (items.length === 0) return;

                  if (e.key === "ArrowDown") {
                    e.preventDefault();
                    this.selectedIndex = Math.min(this.selectedIndex + 1, items.length - 1);
                    this.updateSelection(items);
                  } else if (e.key === "ArrowUp") {
                    e.preventDefault();
                    this.selectedIndex = Math.max(this.selectedIndex - 1, -1);
                    this.updateSelection(items);
                  } else if (e.key === "Enter") {
                    e.preventDefault();
                    if (this.selectedIndex >= 0 && this.selectedIndex < items.length) {
                      items[this.selectedIndex].click();
                    } else {
                      const value = this.input.value.trim().toLowerCase();
                      if (value) {
                        this.pushEventTo(this.el, "add_genre", { genre: value });
                      }
                    }
                    this.input.value = "";
                  } else if (e.key === "Escape") {
                    e.preventDefault();
                    this.input.value = "";
                    this.pushEventTo(this.el, "search_genres", { value: "" });
                  }
                });
              },
              updated() {
                this.selectedIndex = -1;
              },
              updateSelection(items) {
                items.forEach((item, i) => {
                  if (i === this.selectedIndex) {
                    item.setAttribute("aria-selected", "true");
                  } else {
                    item.removeAttribute("aria-selected");
                  }
                });
              },
              destroyed() {
                clearTimeout(this.debounceTimer);
              }
            }
          </script>
        </div>
        <div class="space-y-4">
          <div class="flex items-center gap-x-2">
            <.label for="dominant_colors">
              {gettext("Dominant Colors")}
            </.label>
            <.button type="button" size="sm" phx-click="rotate_dominant_colors" phx-target={@myself}>
              <.icon name="hero-arrows-right-left" class="icon" aria-hidden="true" data-slot="icon" />
              {gettext("Rotate colors")}
            </.button>
          </div>
          <div class="mt-2 grid grid-cols-5 gap-2">
            <div :for={color <- @form[:dominant_colors].value} class="flex flex-col items-center">
              <input
                type="color"
                name="record[dominant_colors][]"
                value={color}
                class="size-12 cursor-pointer rounded border border-zinc-300 md:size-16"
              />
              <span class="mt-1 text-xs text-zinc-600 md:text-sm dark:text-zinc-400">
                {String.upcase(color)}
              </span>
            </div>
          </div>
        </div>
        <div class="col-span-full">
          <.label for={@uploads.cover_data.ref}>
            {gettext("Cover art")}
          </.label>
          <div
            phx-drop-target={@uploads.cover_data.ref}
            class={[
              "mt-2 flex justify-center rounded-lg",
              "border border-dashed border-zinc-300",
              "px-6 py-10"
            ]}
          >
            <div class="text-center">
              <.record_cover
                :if={@uploads.cover_data.entries == []}
                record={@record}
              />
              <.live_img_preview
                :for={entry <- @uploads.cover_data.entries}
                class="mx-auto w-full"
                entry={entry}
              />
              <div class="mt-4 text-sm/6 text-zinc-600 dark:text-zinc-400">
                <%= for entry <- @uploads.cover_data.entries do %>
                  <span>{entry.progress}%</span>
                <% end %>
              </div>
              <div class="mt-4 text-sm/6 text-zinc-600 dark:text-zinc-300">
                <label
                  for={@uploads.cover_data.ref}
                  class={[
                    "cursor-pointer rounded-md font-semibold",
                    "focus-within:ring-2 focus-within:ring-indigo-600 focus-within:ring-offset-2 focus-within:outline-none",
                    "hover:text-zinc-200"
                  ]}
                >
                  <span>{gettext("Upload a file")}</span>
                  <.live_file_input class="sr-only" upload={@uploads.cover_data} />
                </label>
                <p class="pl-1">{gettext("or drag and drop")}</p>
              </div>
              <p class="text-xs/5 text-zinc-600 dark:text-zinc-400">
                {gettext("PNG, JPG, WEBP up to 8MB")}
              </p>
            </div>
          </div>
        </div>
        <div class="col-span-full space-y-4">
          <.label>{gettext("Search for cover art online")}</.label>
          <div class="flex gap-2">
            <div class="flex-1">
              <.input
                type="text"
                id="cover-search-query"
                name="cover_search_query"
                value={@cover_search_query}
                phx-keyup="update_cover_search_query"
                phx-keydown="search_covers"
                phx-key="Enter"
                phx-target={@myself}
                onkeydown="if(event.key==='Enter')event.preventDefault()"
              />
            </div>
            <.button
              type="button"
              size="sm"
              id="cover-search-button"
              phx-click="search_covers"
              phx-target={@myself}
              disabled={@cover_search_loading}
            >
              <.icon
                :if={@cover_search_loading}
                name="hero-arrow-path"
                class="icon animate-spin"
                aria-hidden="true"
                data-slot="icon"
              />
              <.icon
                :if={!@cover_search_loading}
                name="hero-magnifying-glass"
                class="icon"
                aria-hidden="true"
                data-slot="icon"
              />
              {gettext("Search")}
            </.button>
          </div>
          <p :if={@cover_search_error} class="text-sm text-red-600 dark:text-red-400">
            {@cover_search_error}
          </p>
          <div
            :if={@cover_search_results != []}
            id="cover-search-results"
            class="grid grid-cols-3 gap-2 sm:grid-cols-4"
          >
            <button
              :for={result <- @cover_search_results}
              type="button"
              phx-click="select_cover"
              phx-value-url={result.image_url}
              phx-target={@myself}
              disabled={@cover_search_loading}
              class={[
                "group relative overflow-hidden rounded-md",
                "border border-zinc-200 dark:border-zinc-700",
                "hover:ring-2 hover:ring-indigo-500",
                "focus:ring-2 focus:ring-indigo-500 focus:outline-none",
                "disabled:cursor-not-allowed disabled:opacity-50"
              ]}
            >
              <img
                src={result.thumbnail_url}
                alt={result.title}
                class="aspect-square w-full object-cover"
                loading="lazy"
              />
              <span
                :if={result.width && result.height}
                class={[
                  "absolute inset-x-0 bottom-0",
                  "bg-black/60 text-center text-xs text-white",
                  "py-0.5"
                ]}
              >
                {result.width}&times;{result.height}
              </span>
            </button>
          </div>
        </div>
        <:actions>
          <div class="w-full md:flex md:justify-center">
            <.button variant="solid" class="w-full md:w-auto" phx-disable-with={gettext("Saving...")}>
              {gettext("Save")}
            </.button>
          </div>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  attr :release, :map, required: true

  defp release_option(assigns) do
    ~H"""
    <div class={[
      "cursor-default rounded-md px-2 py-1 md:px-3 md:py-2",
      "in-data-highlighted:bg-zinc-100 dark:in-data-highlighted:bg-zinc-600",
      "[[data-highlighted]_&]:flx-focus:bg-zinc-100"
    ]}>
      <.release_summary release={@release} class="max-w-74 sm:max-w-none" />
    </div>
    """
  end

  @impl true
  def update(%{record: record} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:form, fn ->
       to_form(Records.change_record(record))
     end)
     |> assign_new(:all_genres, fn -> Records.list_genres() end)
     |> assign_new(:genre_query, fn -> "" end)
     |> assign_new(:genre_suggestions, fn -> [] end)
     |> assign_new(:cover_search_query, fn ->
       "#{Record.artist_names(record)} #{record.title} album cover"
     end)
     |> assign_new(:cover_search_results, fn -> [] end)
     |> assign_new(:cover_search_loading, fn -> false end)
     |> assign_new(:cover_search_error, fn -> nil end)}
  end

  @impl true
  def handle_event("validate", %{"record" => record_params}, socket) do
    changeset = Records.change_record(socket.assigns.record, record_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  # path comes from Phoenix's consume_uploaded_entries callback —
  # a framework-generated temp file path, not user input.
  # sobelow_skip ["Traversal.FileModule"]
  def handle_event("save", %{"record" => record_params}, socket) do
    uploaded_covers =
      consume_uploaded_entries(socket, :cover_data, fn %{path: path}, entry ->
        params = %{content: File.read!(path), format: entry.client_type}
        {:ok, params}
      end)

    save_record(socket, record_params, uploaded_covers)
  end

  def handle_event("recover_form", params, socket) do
    handle_event("validate", params, socket)
  end

  def handle_event("rotate_dominant_colors", _params, socket) do
    changeset = Record.rotate_dominant_colors(socket.assigns.form.source)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("search_genres", %{"value" => query}, socket) do
    current_genres = get_current_genres(socket.assigns)
    query = String.trim(query)

    suggestions =
      if query == "" do
        []
      else
        downcased_query = String.downcase(query)

        socket.assigns.all_genres
        |> Enum.filter(fn g ->
          String.contains?(String.downcase(g), downcased_query) and g not in current_genres
        end)
        |> Enum.take(10)
      end

    {:noreply,
     socket
     |> assign(:genre_query, query)
     |> assign(:genre_suggestions, suggestions)}
  end

  def handle_event("add_genre", %{"genre" => genre}, socket) do
    genre = genre |> String.trim() |> String.downcase()
    current_genres = get_current_genres(socket.assigns)

    if genre == "" or genre in current_genres do
      {:noreply, socket |> assign(:genre_query, "") |> assign(:genre_suggestions, [])}
    else
      new_genres = current_genres ++ [genre]
      params = Map.merge(socket.assigns.form.params, %{"genres" => new_genres})
      changeset = Records.change_record(socket.assigns.record, params)

      {:noreply,
       socket
       |> assign(:form, to_form(changeset, action: :validate))
       |> assign(:genre_query, "")
       |> assign(:genre_suggestions, [])}
    end
  end

  def handle_event("remove_genre", %{"genre" => genre}, socket) do
    current_genres = get_current_genres(socket.assigns)
    new_genres = Enum.reject(current_genres, &(&1 == genre))
    params = Map.merge(socket.assigns.form.params, %{"genres" => new_genres})
    changeset = Records.change_record(socket.assigns.record, params)

    {:noreply, assign(socket, :form, to_form(changeset, action: :validate))}
  end

  def handle_event("update_cover_search_query", %{"value" => query}, socket) do
    {:noreply, assign(socket, :cover_search_query, query)}
  end

  def handle_event("search_covers", _params, socket) do
    query = socket.assigns.cover_search_query

    {:noreply,
     socket
     |> assign(:cover_search_loading, true)
     |> assign(:cover_search_error, nil)
     |> start_async(:cover_search, fn -> BraveSearch.search_images(query, count: 20) end)}
  end

  def handle_event("select_cover", %{"url" => url}, socket) do
    {:noreply,
     socket
     |> assign(:cover_search_loading, true)
     |> assign(:cover_search_error, nil)
     |> start_async(:cover_download, fn ->
       with {:ok, data} <- BraveSearch.download_image(url),
            {:ok, resized} <- Image.resize(data),
            {:ok, asset} <- Assets.store_image(%{content: resized, format: "image/jpeg"}) do
         {:ok, asset.hash}
       end
     end)}
  end

  @impl true
  def handle_async(:cover_search, {:ok, {:ok, results}}, socket) do
    {:noreply,
     socket
     |> assign(:cover_search_results, results)
     |> assign(:cover_search_loading, false)}
  end

  def handle_async(:cover_search, {:ok, {:error, reason}}, socket) do
    {:noreply,
     socket
     |> assign(
       :cover_search_error,
       gettext("Search failed") <> ": " <> ErrorMessages.friendly_message(reason)
     )
     |> assign(:cover_search_loading, false)}
  end

  def handle_async(:cover_search, {:exit, reason}, socket) do
    {:noreply,
     socket
     |> assign(
       :cover_search_error,
       gettext("Search failed") <> ": " <> ErrorMessages.friendly_message(reason)
     )
     |> assign(:cover_search_loading, false)}
  end

  def handle_async(:cover_download, {:ok, {:ok, cover_hash}}, socket) do
    case Records.update_record(socket.assigns.record, %{"cover_hash" => cover_hash}) do
      {:ok, record} ->
        notify_parent({:saved, record})

        {:noreply,
         socket
         |> assign(:cover_search_loading, false)
         |> put_toast(:info, gettext("Cover art updated successfully"))
         |> push_patch(to: socket.assigns.patch)}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> assign(:cover_search_error, gettext("Failed to save cover art"))
         |> assign(:cover_search_loading, false)}
    end
  end

  def handle_async(:cover_download, {:ok, {:error, reason}}, socket) do
    {:noreply,
     socket
     |> assign(
       :cover_search_error,
       gettext("Download failed") <> ": " <> ErrorMessages.friendly_message(reason)
     )
     |> assign(:cover_search_loading, false)}
  end

  def handle_async(:cover_download, {:exit, reason}, socket) do
    {:noreply,
     socket
     |> assign(
       :cover_search_error,
       gettext("Download failed") <> ": " <> ErrorMessages.friendly_message(reason)
     )
     |> assign(:cover_search_loading, false)}
  end

  defp save_record(socket, record_params, uploaded_covers) do
    with {:ok, params} <- maybe_store_uploaded_cover(record_params, uploaded_covers),
         {:ok, record} <- Records.update_record(socket.assigns.record, params) do
      notify_parent({:saved, record})

      {:noreply,
       socket
       |> put_toast(:info, gettext("Record updated successfully"))
       |> push_patch(to: socket.assigns.patch)}
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp maybe_store_uploaded_cover(params, []), do: {:ok, params}

  defp maybe_store_uploaded_cover(params, [cover_params]) do
    case Assets.store_image(cover_params) do
      {:ok, asset} -> {:ok, Map.put(params, "cover_hash", asset.hash)}
      {:error, reason} -> {:error, reason}
    end
  end

  def formats_with_labels do
    Enum.map(Records.Record.formats(), fn f -> {format_label(f), f} end)
  end

  def types_with_labels do
    Enum.map(Records.Record.types(), fn t -> {type_label(t), t} end)
  end

  defp selected_release_id_options(record) do
    record
    |> Records.Record.releases()
    |> Enum.map(fn release ->
      {
        release_label(release),
        release.id
      }
    end)
  end

  defp get_current_genres(assigns) do
    Ecto.Changeset.get_field(assigns.form.source, :genres) || []
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
