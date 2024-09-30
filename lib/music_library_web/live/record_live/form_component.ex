defmodule MusicLibraryWeb.RecordLive.FormComponent do
  use MusicLibraryWeb, :live_component

  alias MusicLibrary.Records

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> allow_upload(:image_data, accept: ~w(.jpg .jpeg), max_entries: 1)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        <%= @title %>
        <:subtitle></:subtitle>
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
        <.input field={@form[:year]} type="number" label="Year" />
        <div>
          <.label for={@uploads.image_data.ref}>
            Cover art
          </.label>
          <.live_file_input
            class="mt-2 block w-full rounded-lg text-zinc-900 focus:ring-0 sm:text-sm sm:leading-6"
            upload={@uploads.image_data}
          />
        </div>
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
    uploaded_images =
      consume_uploaded_entries(socket, :image_data, fn %{path: path}, _entry ->
        {:ok, File.read!(path)}
      end)

    save_record(socket, record_params, uploaded_images)
  end

  defp save_record(socket, record_params, uploaded_images) do
    params =
      case uploaded_images do
        [] -> record_params
        [image_path] -> Map.put(record_params, "image_data", image_path)
      end

    case Records.update_record(socket.assigns.record, params) do
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
