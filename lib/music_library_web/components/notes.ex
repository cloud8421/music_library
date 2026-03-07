defmodule MusicLibraryWeb.Components.Notes do
  use MusicLibraryWeb, :live_component

  alias MusicLibrary.Notes
  alias MusicLibrary.Notes.Note
  alias MusicLibraryWeb.Markdown

  def open(id), do: Fluxon.open_dialog(id)

  @impl true
  def update(assigns, socket) do
    note = find_or_initialize_note(assigns)

    changeset =
      Note.changeset(note, %{})

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:note, note)
     |> assign(:mode, initial_mode(changeset))
     |> assign(:form, to_form(changeset))}
  end

  defp find_or_initialize_note(%{entity: entity, musicbrainz_id: musicbrainz_id}) do
    case Notes.get_note(entity, musicbrainz_id) do
      nil ->
        %Note{entity: entity, musicbrainz_id: musicbrainz_id}

      note ->
        note
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.sheet
        id={@sheet_id}
        placement="right"
        class="w-md sm:min-w-lg lg:min-w-2xl py-16"
      >
        <.tabs>
          <.tabs_list variant="segmented" class="w-48 mx-auto md:mx-0" active_tab={@mode}>
            <:tab name="read" phx-click="set_mode" phx-value-mode="read" phx-target={@myself}>
              {gettext("Read")}
            </:tab>
            <:tab name="edit" phx-click="set_mode" phx-value-mode="edit" phx-target={@myself}>
              {gettext("Edit")}
            </:tab>
          </.tabs_list>
          <.tabs_panel active={@mode == "read"} name="read">
            <article class="w-full mt-5 prose dark:prose-invert prose-zinc prose-sm prose-h1:text-sm">
              {render_content(@form[:content].value)}
            </article>
          </.tabs_panel>
          <.tabs_panel active={@mode == "edit"} name="edit">
            <.simple_form
              for={@form}
              id="notes-form"
              phx-target={@myself}
              phx-change="validate"
              phx-auto-recover="recover_form"
              phx-submit="save"
            >
              <.textarea
                class={[
                  "w-full min-h-128 md:min-h-164 overflow-scroll font-mono",
                  @form[:content].value != @note.content &&
                    "border-amber-300 focus-visible:border-amber-300"
                ]}
                field={@form[:content]}
              />

              <:actions>
                <div class="w-full md:flex md:justify-center">
                  <.button
                    variant="solid"
                    class="w-full md:w-auto"
                    phx-disable-with={gettext("Saving...")}
                  >
                    {gettext("Save")}
                  </.button>
                </div>
              </:actions>
            </.simple_form>
          </.tabs_panel>
        </.tabs>
      </.sheet>
    </div>
    """
  end

  @impl true
  def handle_event("validate", %{"note" => note_params}, socket) do
    changeset = Notes.change_note(socket.assigns.note, note_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"note" => note_params}, socket) do
    if socket.assigns.note.id do
      update_note(note_params, socket)
    else
      create_note(note_params, socket)
    end
  end

  def handle_event("recover_form", params, socket) do
    handle_event("validate", params, socket)
  end

  def handle_event("set_mode", %{"mode" => mode}, socket) when mode in ["read", "edit"] do
    {:noreply, assign(socket, :mode, mode)}
  end

  defp update_note(note_params, socket) do
    case Notes.update_note(socket.assigns.note, note_params) do
      {:ok, note} ->
        changeset =
          Note.changeset(note, %{})

        {:noreply,
         socket
         |> assign(:note, note)
         |> assign(:form, to_form(changeset))
         |> put_toast(:info, gettext("Note updated successfully"))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp create_note(note_params, socket) do
    case Notes.create_note(socket.assigns.note, note_params) do
      {:ok, note} ->
        changeset =
          Note.changeset(note, %{})

        {:noreply,
         socket
         |> assign(:note, note)
         |> assign(:form, to_form(changeset))
         |> put_toast(:info, gettext("Note created successfully"))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp initial_mode(changeset) do
    if Ecto.Changeset.get_field(changeset, :content) in [nil, ""] do
      "edit"
    else
      "read"
    end
  end

  # sobelow_skip ["XSS.Raw"]
  # Markdown.to_html/1 sanitizes HTML via HtmlSanitizeEx
  defp render_content(content) do
    content
    |> Markdown.to_html()
    |> raw()
  end
end
