defmodule MusicLibraryWeb.NotesComponent do
  use MusicLibraryWeb, :live_component

  alias MusicLibrary.Records

  def open(id), do: Fluxon.open_dialog(id)

  @impl true
  def update(assigns, socket) do
    changeset =
      assigns.record
      |> Records.change_record()

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:form, to_form(changeset))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.sheet
        id={@sheet_id}
        placement="right"
        class="min-w-xs sm:min-w-lg lg:min-w-2xl"
      >
        <.simple_form
          for={@form}
          id="record-notes-form"
          phx-target={@myself}
          phx-change="validate"
          phx-auto-recover="recover_form"
          phx-submit="save"
        >
          <.textarea class="w-full h-96 font-mono" field={@form[:notes]} label={gettext("Notes")} />
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
      </.sheet>
    </div>
    """
  end

  @impl true
  def handle_event("validate", %{"record" => record_params}, socket) do
    changeset = Records.change_record(socket.assigns.record, record_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"record" => record_params}, socket) do
    case Records.update_record(socket.assigns.record, record_params) do
      {:ok, _record} ->
        {:noreply,
         socket
         |> put_toast(:info, gettext("Record updated successfully"))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  def handle_event("recover_form", params, socket) do
    handle_event("validate", params, socket)
  end
end
