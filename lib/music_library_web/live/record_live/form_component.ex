defmodule MusicLibraryWeb.RecordLive.FormComponent do
  use MusicLibraryWeb, :live_component

  alias MusicLibrary.Records

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        <%= @title %>
        <:subtitle>Use this form to manage record records in your database.</:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="record-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input
          field={@form[:type]}
          type="select"
          label="Type"
          prompt="Choose a value"
          options={Ecto.Enum.values(MusicLibrary.Records.Record, :type)}
        />
        <.input field={@form[:title]} type="text" label="Title" />
        <.input field={@form[:musicbrainz_id]} type="text" label="Musicbrainz" />
        <.input field={@form[:year]} type="number" label="Year" />
        <.input
          field={@form[:genres]}
          type="select"
          multiple
          label="Genres"
          options={[{"Option 1", "option1"}, {"Option 2", "option2"}]}
        />
        <.input field={@form[:image_url]} type="text" label="Image url" />
        <:actions>
          <.button phx-disable-with="Saving...">Save Record</.button>
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
    save_record(socket, socket.assigns.action, record_params)
  end

  defp save_record(socket, :edit, record_params) do
    case Records.update_record(socket.assigns.record, record_params) do
      {:ok, record} ->
        notify_parent({:saved, record})

        {:noreply,
         socket
         |> put_flash(:info, "Record updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
