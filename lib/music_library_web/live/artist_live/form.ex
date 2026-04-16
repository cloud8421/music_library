defmodule MusicLibraryWeb.ArtistLive.Form do
  use MusicLibraryWeb, :live_component

  import MusicLibraryWeb.RecordComponents, only: [artist_image: 1]

  alias MusicLibrary.Artists
  alias MusicLibrary.Assets
  alias MusicLibrary.Assets.Image
  alias MusicLibraryWeb.ErrorMessages

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> allow_upload(:image_data, accept: ~w(.jpg .jpeg .png .webp), max_entries: 1)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="w-full">
      <header>
        <h1 class="text-lg font-semibold text-zinc-900 dark:text-zinc-100">
          {@artist.name}
        </h1>
      </header>

      <.simple_form
        for={@form}
        id="artist-info-form"
        phx-target={@myself}
        phx-change="validate"
        phx-auto-recover="recover_form"
        phx-submit="save"
      >
        <div class="col-span-full">
          <.label for={@uploads.image_data.ref}>
            {gettext("Artist image")}
          </.label>
          <div
            phx-drop-target={@uploads.image_data.ref}
            class={[
              "mt-2 flex justify-center rounded-lg",
              "border border-dashed border-zinc-300",
              "px-6 py-10"
            ]}
          >
            <div class="text-center">
              <.artist_image
                :if={@uploads.image_data.entries == []}
                class="mx-auto w-full rounded-lg"
                artist={@artist}
                image_hash={@artist_info.image_data_hash}
              />
              <.live_img_preview
                :for={entry <- @uploads.image_data.entries}
                class="mx-auto w-full"
                entry={entry}
              />
              <div class="mt-4 text-sm/6 text-zinc-600 dark:text-zinc-400">
                <%= for entry <- @uploads.image_data.entries do %>
                  <span>{entry.progress}%</span>
                <% end %>
              </div>
              <div class="mt-4 text-sm/6 text-zinc-600 dark:text-zinc-300">
                <label
                  for={@uploads.image_data.ref}
                  class={[
                    "relative cursor-pointer rounded-md font-semibold",
                    "focus-within:ring-2 focus-within:ring-indigo-600 focus-within:ring-offset-2 focus-within:outline-none",
                    "hover:text-zinc-200"
                  ]}
                >
                  <span>{gettext("Upload a file")}</span>
                  <.live_file_input class="sr-only" upload={@uploads.image_data} />
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
          <.label>{gettext("Search for artist image online")}</.label>
          <div class="flex gap-2">
            <div class="flex-1">
              <.input
                type="text"
                id="image-search-query"
                name="image_search_query"
                value={@image_search_query}
                phx-keyup="update_image_search_query"
                phx-keydown="search_images"
                phx-key="Enter"
                phx-target={@myself}
                onkeydown="if(event.key==='Enter')event.preventDefault()"
              />
            </div>
            <.button
              type="button"
              size="sm"
              id="image-search-button"
              phx-click="search_images"
              phx-target={@myself}
              disabled={@image_search_loading}
            >
              <.icon
                :if={@image_search_loading}
                name="hero-arrow-path"
                class="icon animate-spin"
                aria-hidden="true"
                data-slot="icon"
              />
              <.icon
                :if={!@image_search_loading}
                name="hero-magnifying-glass"
                class="icon"
                aria-hidden="true"
                data-slot="icon"
              />
              {gettext("Search")}
            </.button>
          </div>
          <p :if={@image_search_error} class="text-sm text-red-600 dark:text-red-400">
            {@image_search_error}
          </p>
          <div
            :if={@image_search_results != []}
            id="image-search-results"
            class="grid grid-cols-3 gap-2 sm:grid-cols-4"
          >
            <button
              :for={result <- @image_search_results}
              type="button"
              phx-click="select_image"
              phx-value-url={result.image_url}
              phx-target={@myself}
              disabled={@image_search_loading}
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

  @impl true
  def update(%{artist_info: artist_info} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:form, fn ->
       to_form(Artists.change_artist_info(artist_info))
     end)
     |> assign_new(:image_search_query, fn -> "#{assigns.artist.name} artist" end)
     |> assign_new(:image_search_results, fn -> [] end)
     |> assign_new(:image_search_loading, fn -> false end)
     |> assign_new(:image_search_error, fn -> nil end)}
  end

  @impl true
  def handle_event("validate", params, socket) do
    artist_info_params = params["artist_info"] || %{}
    changeset = Artists.change_artist_info(socket.assigns.artist_info, artist_info_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  # path comes from Phoenix's consume_uploaded_entries callback —
  # a framework-generated temp file path, not user input.
  # sobelow_skip ["Traversal.FileModule"]
  def handle_event("save", params, socket) do
    artist_info_params = params["artist_info"] || %{}

    uploaded_images =
      consume_uploaded_entries(socket, :image_data, fn %{path: path}, entry ->
        params = %{content: File.read!(path), format: entry.client_type}
        {:ok, params}
      end)

    save_artist_info(socket, artist_info_params, uploaded_images)
  end

  def handle_event("recover_form", params, socket) do
    handle_event("validate", params, socket)
  end

  def handle_event("update_image_search_query", %{"value" => query}, socket) do
    {:noreply, assign(socket, :image_search_query, query)}
  end

  def handle_event("search_images", _params, socket) do
    query = socket.assigns.image_search_query

    {:noreply,
     socket
     |> assign(:image_search_loading, true)
     |> assign(:image_search_error, nil)
     |> start_async(:image_search, fn -> BraveSearch.search_images(query, count: 20) end)}
  end

  def handle_event("select_image", %{"url" => url}, socket) do
    {:noreply,
     socket
     |> assign(:image_search_loading, true)
     |> assign(:image_search_error, nil)
     |> start_async(:image_download, fn ->
       with {:ok, data} <- BraveSearch.download_image(url),
            {:ok, resized} <- Image.resize(data),
            {:ok, asset} <- Assets.store_image(%{content: resized, format: "image/jpeg"}) do
         {:ok, asset.hash}
       end
     end)}
  end

  @impl true
  def handle_async(:image_search, {:ok, {:ok, results}}, socket) do
    {:noreply,
     socket
     |> assign(:image_search_results, results)
     |> assign(:image_search_loading, false)}
  end

  def handle_async(:image_search, {:ok, {:error, reason}}, socket) do
    {:noreply,
     socket
     |> assign(
       :image_search_error,
       gettext("Search failed") <> ": " <> ErrorMessages.friendly_message(reason)
     )
     |> assign(:image_search_loading, false)}
  end

  def handle_async(:image_search, {:exit, reason}, socket) do
    {:noreply,
     socket
     |> assign(
       :image_search_error,
       gettext("Search failed") <> ": " <> ErrorMessages.friendly_message(reason)
     )
     |> assign(:image_search_loading, false)}
  end

  def handle_async(:image_download, {:ok, {:ok, image_hash}}, socket) do
    case Artists.update_artist_info(socket.assigns.artist_info, %{"image_data_hash" => image_hash}) do
      {:ok, artist_info} ->
        notify_parent({:saved, artist_info})

        put_toast!(:info, gettext("Artist image updated successfully"))

        {:noreply,
         socket
         |> assign(:image_search_loading, false)
         |> push_patch(to: socket.assigns.patch)}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> assign(:image_search_error, gettext("Failed to save artist image"))
         |> assign(:image_search_loading, false)}
    end
  end

  def handle_async(:image_download, {:ok, {:error, reason}}, socket) do
    {:noreply,
     socket
     |> assign(
       :image_search_error,
       gettext("Download failed") <> ": " <> ErrorMessages.friendly_message(reason)
     )
     |> assign(:image_search_loading, false)}
  end

  def handle_async(:image_download, {:exit, reason}, socket) do
    {:noreply,
     socket
     |> assign(
       :image_search_error,
       gettext("Download failed") <> ": " <> ErrorMessages.friendly_message(reason)
     )
     |> assign(:image_search_loading, false)}
  end

  defp save_artist_info(socket, artist_info_params, uploaded_images) do
    with {:ok, params} <- maybe_store_uploaded_image(artist_info_params, uploaded_images),
         {:ok, artist_info} <- Artists.update_artist_info(socket.assigns.artist_info, params) do
      notify_parent({:saved, artist_info})

      put_toast!(:info, gettext("Artist updated successfully"))
      {:noreply, push_patch(socket, to: socket.assigns.patch)}
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}

      {:error, _reason} ->
        put_toast!(:error, gettext("Failed to store artist image"))
        {:noreply, socket}
    end
  end

  defp maybe_store_uploaded_image(params, []), do: {:ok, params}

  defp maybe_store_uploaded_image(params, [image_params]) do
    case Assets.store_image(image_params) do
      {:ok, asset} -> {:ok, Map.put(params, "image_data_hash", asset.hash)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
