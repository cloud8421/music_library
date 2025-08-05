defmodule MusicLibraryWeb.ArtistLive.FormComponent do
  use MusicLibraryWeb, :live_component

  alias MusicLibrary.Artists
  alias Vix.Vips.Image

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> allow_upload(:image_data, accept: ~w(.jpg .jpeg .png .webp), max_entries: 1)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="w-82 md:w-2xl">
      <header>
        <h1 class="text-base font-medium leading-6 text-zinc-700">
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
              <img
                :if={@uploads.image_data.entries == []}
                class="rounded-lg mx-auto w-full"
                alt={@artist.name}
                src={~p"/artists/#{@artist_info.id}/image?vsn=#{@artist_info.image_data_hash || ""}"}
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
                    "focus-within:outline-none focus-within:ring-2 focus-within:ring-indigo-600 focus-within:ring-offset-2",
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
     end)}
  end

  @impl true
  def handle_event("validate", params, socket) do
    artist_info_params = params["artist_info"] || %{}
    changeset = Artists.change_artist_info(socket.assigns.artist_info, artist_info_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", params, socket) do
    artist_info_params = params["artist_info"] || %{}

    uploaded_images =
      consume_uploaded_entries(socket, :image_data, fn %{path: path}, _entry ->
        {:ok, File.read!(path)}
      end)

    save_artist_info(socket, artist_info_params, uploaded_images)
  end

  def handle_event("recover_form", params, socket) do
    handle_event("validate", params, socket)
  end

  defp save_artist_info(socket, artist_info_params, uploaded_images) do
    params =
      case uploaded_images do
        [] ->
          artist_info_params

        [image_data] ->
          {:ok, image} = Image.new_from_buffer(image_data)

          image_width = Image.width(image)

          Map.merge(artist_info_params, %{
            "image_data" => image_data,
            "image_data_width" => image_width
          })
      end

    case Artists.update_artist_info(socket.assigns.artist_info, params) do
      {:ok, artist_info} ->
        notify_parent({:saved, artist_info})

        {:noreply,
         socket
         |> put_toast(:info, gettext("Artist updated successfully"))
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
