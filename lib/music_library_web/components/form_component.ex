defmodule MusicLibraryWeb.FormComponent do
  use MusicLibraryWeb, :live_component

  import MusicLibraryWeb.RecordComponents,
    only: [format_label: 1, type_label: 1, release_label: 1, release_summary: 1]

  alias MusicLibrary.Records
  alias MusicLibrary.Records.{Cover, Record}

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
        <h1 class="text-sm font-medium leading-6 text-zinc-700 dark:text-zinc-400">
          {Record.artist_names(@record)}
        </h1>
        <h2 class="text-base font-medium leading-6 text-zinc-700 dark:text-zinc-400">
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
        <div class="sm:columns-2 space-y-2">
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
          <.input field={@form[:release_date]} label={gettext("Release Date")} />
          <.date_time_picker
            :if={@show_purchased_at}
            field={@form[:purchased_at]}
            display_format="%B %-d, %Y at %I:%M %p"
            label={gettext("Purchased at")}
          />
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
              <svg
                :if={@uploads.cover_data.entries == []}
                class="mx-auto size-24 text-zinc-300"
                viewBox="0 0 24 24"
                fill="currentColor"
                aria-hidden="true"
                data-slot="icon"
              >
                <path
                  fill-rule="evenodd"
                  d="M1.5 6a2.25 2.25 0 0 1 2.25-2.25h16.5A2.25 2.25 0 0 1 22.5 6v12a2.25 2.25 0 0 1-2.25 2.25H3.75A2.25 2.25 0 0 1 1.5 18V6ZM3 16.06V18c0 .414.336.75.75.75h16.5A.75.75 0 0 0 21 18v-1.94l-2.69-2.689a1.5 1.5 0 0 0-2.12 0l-.88.879.97.97a.75.75 0 1 1-1.06 1.06l-5.16-5.159a1.5 1.5 0 0 0-2.12 0L3 16.061Zm10.125-7.81a1.125 1.125 0 1 1 2.25 0 1.125 1.125 0 0 1-2.25 0Z"
                  clip-rule="evenodd"
                />
              </svg>
              <.live_img_preview
                :for={entry <- @uploads.cover_data.entries}
                class="mx-auto size-24"
                entry={entry}
              />
              <div class="mt-4 text-sm/6 text-zinc-600 dark:text-zinc-400">
                <%= for entry <- @uploads.cover_data.entries do %>
                  <span>{entry.progress}%</span>
                <% end %>
              </div>
              <div class="mt-4 flex text-sm/6 text-zinc-600 dark:text-zinc-300">
                <label
                  for={@uploads.cover_data.ref}
                  class={[
                    "relative cursor-pointer rounded-md font-semibold",
                    "focus-within:outline-none focus-within:ring-2 focus-within:ring-indigo-600 focus-within:ring-offset-2",
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
      "cursor-default px-2 py-1 md:px-3 md:py-2 rounded-md",
      "in-data-highlighted:bg-zinc-100 dark:in-data-highlighted:bg-zinc-600",
      "[[data-highlighted]_&]:flx-focus:bg-zinc-100"
    ]}>
      <.release_summary release={@release} />
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

  def handle_event("recover_form", params, socket) do
    handle_event("validate", params, socket)
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

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
