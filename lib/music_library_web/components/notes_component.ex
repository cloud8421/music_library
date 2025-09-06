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
     |> assign(:mode, initial_mode(assigns.record))
     |> assign(:form, to_form(changeset))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.sheet
        id={@sheet_id}
        placement="right"
        class="min-w-xs max-w-lg sm:min-w-lg lg:min-w-2xl py-16"
      >
        <.tabs>
          <.tabs_list variant="segmented" active_tab={@mode}>
            <:tab name="read" phx-click="set_mode" phx-value-mode="read" phx-target={@myself}>
              {gettext("Read")}
            </:tab>
            <:tab name="edit" phx-click="set_mode" phx-value-mode="edit" phx-target={@myself}>
              {gettext("Edit")}
            </:tab>
          </.tabs_list>
          <.tabs_panel active={@mode == "read"} name="read">
            <div class="w-full mt-10 text-sm/8">
              {render_notes(@form[:notes].value)}
            </div>
          </.tabs_panel>
          <.tabs_panel active={@mode == "edit"} name="edit">
            <.simple_form
              for={@form}
              id="record-notes-form"
              phx-target={@myself}
              phx-change="validate"
              phx-auto-recover="recover_form"
              phx-submit="save"
            >
              <.textarea class="w-full h-96 font-mono text-sm/8" field={@form[:notes]} />

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

  def handle_event("set_mode", %{"mode" => mode}, socket) when mode in ["read", "edit"] do
    {:noreply, assign(socket, :mode, mode)}
  end

  defp initial_mode(record) when record.notes in [nil, ""], do: "edit"
  defp initial_mode(_record), do: "read"

  defp render_notes(notes) do
    add_a_classes =
      &Earmark.AstTools.merge_atts_in_node(&1,
        class:
          "underline text-zinc-700 hover:text-zinc-500 dark:text-zinc-400 dark:hover:text-zinc-300"
      )

    tsp = Earmark.TagSpecificProcessors.new([{"a", add_a_classes}])

    (notes || "")
    |> Earmark.as_html!(%Earmark.Options{gfm: true, registered_processors: [tsp]})
    |> raw()
  end
end
