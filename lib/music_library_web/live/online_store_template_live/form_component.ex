defmodule MusicLibraryWeb.OnlineStoreTemplateLive.FormComponent do
  use MusicLibraryWeb, :live_component

  alias MusicLibrary.Artists.Artist
  alias MusicLibrary.OnlineStoreTemplates
  alias MusicLibrary.Records.Record

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
        id="online_store_template-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input
          field={@form[:name]}
          type="text"
          label={gettext("Template Name")}
          placeholder={gettext("e.g. Amazon UK")}
        />

        <.input
          field={@form[:url_template]}
          type="text"
          label={gettext("URL Template")}
          placeholder={gettext("e.g. https://www.amazon.co.uk/s?k={artist}+{title}+vinyl")}
          class="font-mono"
          help_text={@generated_url_preview}
        />

        <.textarea
          field={@form[:description]}
          label={gettext("Description (optional)")}
          placeholder={gettext("Add a description to help identify this template")}
        />

        <.switch field={@form[:enabled]} label={gettext("Enable this template")} />

        <div class="mt-4 p-4 bg-gray-50 dark:bg-gray-800 rounded-lg">
          <h4 class="text-sm font-medium text-gray-900 dark:text-white mb-2">
            {gettext("Available Variables")}
          </h4>
          <div class="text-sm text-gray-600 dark:text-gray-400">
            <p>
              <code class="bg-gray-200 dark:bg-gray-700 px-1 rounded">{"{artist}"}</code>
              - {gettext("Artist name(s)")}
            </p>
            <p>
              <code class="bg-gray-200 dark:bg-gray-700 px-1 rounded">{"{title}"}</code>
              - {gettext("Record title")}
            </p>
            <p>
              <code class="bg-gray-200 dark:bg-gray-700 px-1 rounded">{"{format}"}</code>
              - {gettext("Record format")}
            </p>
          </div>
        </div>

        <:actions>
          <.button phx-disable-with={gettext("Saving...")}>
            {gettext("Save Template")}
          </.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{template: template} = assigns, socket) do
    test_record = %Record{
      title: "Dark Side of the Moon",
      artists: [%Artist{name: "Pink Floyd"}],
      format: :vinyl
    }

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:test_record, test_record)
     |> assign(:generated_url_preview, generate_preview(template, test_record))
     |> assign_new(:form, fn ->
       to_form(OnlineStoreTemplates.change_template(template))
     end)}
  end

  @impl true
  def handle_event("validate", %{"online_store_template" => template_params}, socket) do
    changeset =
      OnlineStoreTemplates.change_template(socket.assigns.template, template_params)

    new_template = Ecto.Changeset.apply_changes(changeset)

    {:noreply,
     socket
     |> assign(:generated_url_preview, generate_preview(new_template, socket.assigns.test_record))
     |> assign(form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"online_store_template" => template_params}, socket) do
    save_template(socket, socket.assigns.action, template_params)
  end

  defp save_template(socket, :edit, template_params) do
    case OnlineStoreTemplates.update_template(socket.assigns.template, template_params) do
      {:ok, template} ->
        notify_parent({:saved, template})

        {:noreply,
         socket
         |> put_flash(:info, gettext("Online store template updated successfully"))
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_template(socket, :new, template_params) do
    case OnlineStoreTemplates.create_template(template_params) do
      {:ok, template} ->
        notify_parent({:saved, template})

        {:noreply,
         socket
         |> put_flash(:info, gettext("Online store template created successfully"))
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp generate_preview(template, _record) when is_nil(template.url_template),
    do: gettext("Preview not available")

  defp generate_preview(template, record) do
    OnlineStoreTemplates.generate_url(template, record)
  end
end
