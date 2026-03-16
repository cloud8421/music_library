defmodule MusicLibraryWeb.OnlineStoreTemplateLive.Index do
  use MusicLibraryWeb, :live_view

  alias MusicLibrary.OnlineStoreTemplates
  alias MusicLibrary.OnlineStoreTemplates.OnlineStoreTemplate

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_section={@current_section} socket={@socket}>
      <header class="mb-6">
        <div class="flex items-center justify-between">
          <div>
            <h1 class="text-2xl font-bold text-zinc-900 dark:text-zinc-100">
              {gettext("Online Store Templates")}
            </h1>
          </div>
          <div>
            <.button variant="solid" size="sm" patch={~p"/online-store-templates/new"}>
              <.icon name="hero-plus" class="icon" aria-hidden="true" data-slot="icon" />
              {gettext("Add")}
            </.button>
          </div>
        </div>
      </header>

      <div class="mt-6 space-y-4">
        <ul
          role="list"
          class="divide-y divide-zinc-100 dark:divide-zinc-300/20"
          phx-update="stream"
          id="templates"
        >
          <li
            :for={{id, template} <- @streams.templates}
            id={id}
            class="flex items-center justify-between py-5"
          >
            <div class="min-w-0">
              <div class="flex items-center gap-x-2">
                <img
                  src={favicon_url(template.url_template)}
                  alt={template.name}
                />
                <p class="text-sm font-semibold text-zinc-900 dark:text-zinc-100">
                  {template.name}
                </p>
                <.badge :if={template.enabled} color="success">
                  {gettext("Enabled")}
                </.badge>
                <.badge :if={!template.enabled} color="warning">
                  {gettext("Disabled")}
                </.badge>
              </div>
              <div class="mt-1 flex items-center gap-x-2 text-xs text-zinc-500 dark:text-zinc-400">
                <p class="truncate font-mono">{template.url_template}</p>
              </div>
              <p :if={template.description} class="mt-1 text-xs text-zinc-500 dark:text-zinc-400">
                {template.description}
              </p>
            </div>
            <div class="flex items-center">
              <.dropdown id={"actions-#{template.id}"} placement="bottom-end">
                <:toggle>
                  <.button variant="ghost">
                    <span class="sr-only">{gettext("Actions")}</span>
                    <.icon
                      name="hero-ellipsis-vertical"
                      class="h-5 w-5 text-zinc-500 dark:text-zinc-400 cursor-pointer"
                      aria-hidden="true"
                      data-slot="icon"
                    />
                  </.button>
                </:toggle>
                <.dropdown_button phx-click="toggle-enabled" phx-value-id={template.id}>
                  {if template.enabled,
                    do: gettext("Disable template"),
                    else: gettext("Enable template")}
                </.dropdown_button>
                <.dropdown_link
                  id={"actions-#{template.id}-edit"}
                  patch={~p"/online-store-templates/#{template}/edit"}
                >
                  {gettext("Edit")}
                </.dropdown_link>
                <.dropdown_separator />
                <.dropdown_button
                  phx-click="delete"
                  phx-value-id={template.id}
                  data-confirm={gettext("Are you sure?")}
                  class={[
                    "text-red-900! hover:bg-red-50! dark:text-red-500! dark:hover:bg-red-900/30! dark:hover:text-red-600!"
                  ]}
                >
                  {gettext("Delete")}
                </.dropdown_button>
              </.dropdown>
            </div>
          </li>
        </ul>
      </div>

      <.structured_modal
        :if={@live_action in [:new, :edit]}
        id="template-modal"
        on_close={JS.patch(~p"/online-store-templates")}
      >
        <.live_component
          module={MusicLibraryWeb.OnlineStoreTemplateLive.Form}
          id={@template.id || :new}
          title={@page_title}
          action={@live_action}
          template={@template}
          patch={~p"/online-store-templates"}
        />
      </.structured_modal>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:current_section, :online_store_templates)
     |> stream(:templates, OnlineStoreTemplates.list_templates())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, gettext("Edit Online Store Template"))
    |> assign(:template, OnlineStoreTemplates.get_template!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, gettext("New Online Store Template"))
    |> assign(:template, %OnlineStoreTemplate{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, gettext("Online Store Templates"))
    |> assign(:template, nil)
  end

  @impl true
  def handle_info(
        {MusicLibraryWeb.OnlineStoreTemplateLive.Form, {:saved, template}},
        socket
      ) do
    {:noreply, stream_insert(socket, :templates, template)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    template = OnlineStoreTemplates.get_template!(id)
    {:ok, _} = OnlineStoreTemplates.delete_template(template)

    {:noreply, stream_delete(socket, :templates, template)}
  end

  @impl true
  def handle_event("toggle-enabled", %{"id" => id}, socket) do
    template = OnlineStoreTemplates.get_template!(id)

    {:ok, updated_template} =
      OnlineStoreTemplates.update_template(template, %{enabled: !template.enabled})

    {:noreply, stream_insert(socket, :templates, updated_template)}
  end
end
