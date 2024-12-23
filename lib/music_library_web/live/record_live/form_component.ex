defmodule MusicLibraryWeb.RecordLive.FormComponent do
  use MusicLibraryWeb, :live_component

  alias MusicLibrary.Records
  alias MusicLibrary.Records.Cover

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> allow_upload(:cover_data, accept: ~w(.jpg .jpeg .png .webp), max_entries: 1)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <header>
        <h1 class="text-base font-medium leading-6 text-zinc-700 dark:text-zinc-400">
          {@title}
        </h1>
      </header>

      <.simple_form
        for={@form}
        id="record-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <div class="sm:columns-2">
          <.input
            field={@form[:type]}
            type="select"
            label={gettext("Type")}
            prompt={gettext("Choose a value")}
            options={Ecto.Enum.values(MusicLibrary.Records.Record, :type)}
          />
          <.input
            field={@form[:format]}
            type="select"
            label={gettext("Format")}
            prompt={gettext("Choose a value")}
            options={Ecto.Enum.values(MusicLibrary.Records.Record, :format)}
          />
        </div>
        <.input field={@form[:musicbrainz_id]} type="text" label={gettext("MusicBrainz ID")} />
        <.input field={@form[:release]} type="text" label={gettext("Release")} />
        <.input
          :if={@show_purchased_at}
          field={@form[:purchased_at]}
          type="datetime-local"
          label={gettext("Purchased at")}
        />
        <div phx-drop-target={@uploads.cover_data.ref}>
          <.label for={@uploads.cover_data.ref}>
            {gettext("Cover art")}
          </.label>
          <span
            :if={@uploads.cover_data.entries == []}
            class="text-xs sm:text-sm float-right text-zinc-700 dark:text-zinc-400"
          >
            {gettext("No cover selected")}
          </span>
          <%= for entry <- @uploads.cover_data.entries do %>
            <span class="float-right text-zinc-700 dark:text-zinc-400">{entry.progress}%</span>
          <% end %>
          <.live_file_input
            class="mt-2 block w-full rounded-lg text-zinc-900 dark:text-zinc-200 focus:ring-0 text-xs sm:text-sm sm:leading-6"
            upload={@uploads.cover_data}
          />
        </div>
        <:actions>
          <.button phx-disable-with={gettext("Saving...")}>{gettext("Save")}</.button>
        </:actions>
      </.simple_form>
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
     end)}
  end

  @impl true
  def handle_event("validate", %{"record" => record_params}, socket) do
    changeset = Records.change_record(socket.assigns.record, record_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"record" => record_params}, socket) do
    uploaded_covers =
      consume_uploaded_entries(socket, :cover_data, fn %{path: path}, _entry ->
        {:ok, File.read!(path)}
      end)

    save_record(socket, record_params, uploaded_covers)
  end

  defp save_record(socket, record_params, uploaded_covers) do
    params =
      case uploaded_covers do
        [] ->
          record_params

        [cover_data] ->
          {:ok, thumb_data} = Cover.resize(cover_data)
          Map.put(record_params, "cover_data", thumb_data)
      end

    case Records.update_record(socket.assigns.record, params) do
      {:ok, record} ->
        notify_parent({:saved, record})

        {:noreply,
         socket
         |> put_flash(:info, gettext("Record updated successfully"))
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
