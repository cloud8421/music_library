defmodule MusicLibraryWeb.ScrobbledTracksLive.Form do
  use MusicLibraryWeb, :live_component

  alias LastFm.Track
  alias MusicLibrary.ScrobbleActivity

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <header class="mb-6">
        <h1 class="text-lg font-semibold text-zinc-900 dark:text-zinc-100">
          {gettext("Edit Scrobbled Track")}
        </h1>
      </header>

      <.simple_form
        for={@form}
        id="track-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input
          field={@form[:title]}
          type="text"
          label={gettext("Track Title")}
          placeholder={gettext("Track name")}
        />

        <.inputs_for :let={artist} field={@form[:artist]}>
          <.input
            field={artist[:name]}
            type="text"
            label={gettext("Artist Name")}
            placeholder={gettext("Artist name")}
          />
          <.input
            class="font-mono"
            field={artist[:musicbrainz_id]}
            label={gettext("Artist MusicBrainz ID")}
          />
        </.inputs_for>

        <.inputs_for :let={album} field={@form[:album]}>
          <.input
            field={album[:title]}
            type="text"
            label={gettext("Album Title")}
            placeholder={gettext("Album name")}
          />
          <.input
            class="font-mono"
            field={album[:musicbrainz_id]}
            label={gettext("Album MusicBrainz ID")}
          />
        </.inputs_for>

        <div class="flex gap-x-2">
          <img
            class="size-16 rounded-md"
            alt={@form[:title].value}
            src={@form[:cover_url].value}
          />

          <.input
            field={@form[:cover_url]}
            type="url"
            label={gettext("Cover Image URL (optional)")}
            placeholder="https://example.com/cover.jpg"
          />
        </div>

        <:actions>
          <div class="w-full md:flex md:justify-center">
            <.button variant="solid" class="w-full md:w-auto" phx-disable-with={gettext("Saving...")}>
              {gettext("Update Track")}
            </.button>
          </div>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{track: track} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:form, fn ->
       to_form(Track.changeset(track, %{}))
     end)}
  end

  @impl true
  def handle_event("validate", %{"track" => track_params}, socket) do
    changeset = Track.changeset(socket.assigns.track, track_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"track" => track_params}, socket) do
    save_track(socket, track_params)
  end

  defp save_track(socket, track_params) do
    case ScrobbleActivity.update_track(socket.assigns.track, track_params) do
      {:ok, track} ->
        notify_parent({:saved, track})

        put_toast!(:info, gettext("Track updated successfully"))
        {:noreply, push_patch(socket, to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
