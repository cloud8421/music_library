defmodule MusicLibraryWeb.OnlineStoreTemplateLive.Index do
  use MusicLibraryWeb, :live_view

  import MusicLibraryWeb.Components.Pagination
  import MusicLibraryWeb.LiveHelpers.Params

  alias MusicLibrary.OnlineStoreTemplates
  alias MusicLibrary.OnlineStoreTemplates.OnlineStoreTemplate

  @default_list_params %{
    page: 1,
    page_size: 50,
    query: ""
  }

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_section={@current_section} socket={@socket}>
      <header class="gap-6 mb-2">
        <div class="flex items-center justify-between gap-6 mb-2 mt-2">
          <.search_form query={@list_params.query} />
          <.button variant="solid" size="sm" patch={~p"/online-store-templates/new"}>
            <.icon name="hero-plus" class="icon" aria-hidden="true" data-slot="icon" />
            {gettext("Add")}
          </.button>
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
            id="no-templates"
            class="hidden only:block p-8 text-center bg-zinc-50 dark:bg-zinc-800 rounded-lg"
          >
            <.icon name="hero-building-storefront" class="h-12 w-12 text-zinc-400 mx-auto mb-4" />
            <p class="text-zinc-600 dark:text-zinc-400">
              {gettext("No online store templates found")}
            </p>
          </li>

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

        <.pagination id={:bottom_pagination} pagination_params={@list_params} />
      </div>

      <.structured_modal
        :if={@live_action in [:new, :edit]}
        id="template-modal"
        on_close={JS.patch(back_path(@list_params))}
      >
        <.live_component
          module={MusicLibraryWeb.OnlineStoreTemplateLive.Form}
          id={@template.id || :new}
          title={@page_title}
          action={@live_action}
          template={@template}
          patch={back_path(@list_params)}
        />
      </.structured_modal>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :current_section, :online_store_templates)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id} = params) do
    socket
    |> apply_fallback_index(params, :templates, &apply_action/3)
    |> assign(:page_title, gettext("Edit Online Store Template"))
    |> assign(:template, OnlineStoreTemplates.get_template!(id))
  end

  defp apply_action(socket, :new, params) do
    socket
    |> apply_fallback_index(params, :templates, &apply_action/3)
    |> assign(:page_title, gettext("New Online Store Template"))
    |> assign(:template, %OnlineStoreTemplate{})
  end

  defp apply_action(socket, :index, params) do
    query = params["query"]
    total_templates = OnlineStoreTemplates.count_templates(query: query)

    list_params =
      @default_list_params
      |> merge_query(query)
      |> merge_pagination(params, total_templates)

    load_and_assign_templates(socket, list_params)
  end

  defp load_and_assign_templates(socket, list_params) do
    offset = page_to_offset(list_params.page, list_params.page_size)

    templates =
      OnlineStoreTemplates.list_templates(
        query: list_params.query,
        offset: offset,
        limit: list_params.page_size
      )

    socket
    |> assign(:list_params, list_params)
    |> assign(:page_title, gettext("Online Store Templates"))
    |> assign(:template, nil)
    |> stream(:templates, templates, reset: true)
  end

  defp back_path(list_params) do
    qs =
      list_params
      |> Map.take([:page, :page_size, :query])
      |> Enum.filter(fn {_, v} -> v not in ["", nil] end)

    ~p"/online-store-templates?#{qs}"
  end

  @impl true
  def handle_info(
        {MusicLibraryWeb.OnlineStoreTemplateLive.Form, {:saved, template}},
        socket
      ) do
    {:noreply,
     socket
     |> stream_insert(:templates, template)
     |> load_and_assign_templates(socket.assigns.list_params)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    template = OnlineStoreTemplates.get_template!(id)
    {:ok, _} = OnlineStoreTemplates.delete_template(template)

    {:noreply,
     socket
     |> stream_delete(:templates, template)
     |> load_and_assign_templates(socket.assigns.list_params)}
  end

  @impl true
  def handle_event("toggle-enabled", %{"id" => id}, socket) do
    template = OnlineStoreTemplates.get_template!(id)

    {:ok, updated_template} =
      OnlineStoreTemplates.update_template(template, %{enabled: !template.enabled})

    {:noreply, stream_insert(socket, :templates, updated_template)}
  end

  def handle_event("search", %{"query" => query}, socket) do
    qs =
      @default_list_params
      |> Map.put(:query, query)
      |> Map.take([:query, :page, :page_size])

    {:noreply, push_patch(socket, to: ~p"/online-store-templates?#{qs}")}
  end
end
