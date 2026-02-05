defmodule MusicLibraryWeb.RecordSetLive.Form do
  use MusicLibraryWeb, :live_component

  alias MusicLibrary.RecordSets

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <header class="mb-6">
        <h1 class="text-lg font-semibold text-zinc-900 dark:text-zinc-100">
          {@title}
        </h1>
      </header>

      <.simple_form
        for={@form}
        id="record-set-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input
          field={@form[:name]}
          type="text"
          label={gettext("Name")}
          placeholder={gettext("e.g. Favorites, Road Trip, Sunday Morning")}
        />

        <.textarea
          class={[
            "w-full min-h-128 md:min-h-164 overflow-scroll font-mono"
          ]}
          field={@form[:description]}
          label={gettext("Description (optional)")}
          placeholder={gettext("What is this set about?")}
        />

        <:actions>
          <.button phx-disable-with={gettext("Saving...")}>
            {gettext("Save Set")}
          </.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{record_set: record_set} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:form, fn ->
       to_form(RecordSets.change_record_set(record_set))
     end)}
  end

  @impl true
  def handle_event("validate", %{"record_set" => record_set_params}, socket) do
    changeset =
      RecordSets.change_record_set(socket.assigns.record_set, record_set_params)

    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"record_set" => record_set_params}, socket) do
    save_record_set(socket, socket.assigns.action, record_set_params)
  end

  defp save_record_set(socket, :edit, record_set_params) do
    case RecordSets.update_record_set(socket.assigns.record_set, record_set_params) do
      {:ok, record_set} ->
        notify_parent({:updated, record_set})
        put_toast!(:info, gettext("Record set updated successfully"))

        {:noreply, push_patch(socket, to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_record_set(socket, :new, record_set_params) do
    case RecordSets.create_record_set(record_set_params) do
      {:ok, record_set} ->
        notify_parent({:created, record_set})
        put_toast!(:info, gettext("Record set created successfully"))

        {:noreply, push_patch(socket, to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
