defmodule MusicLibraryWeb.OnlineStoreTemplateLive.Index do
  use MusicLibraryWeb, :live_view

  alias MusicLibrary.OnlineStoreTemplates
  alias MusicLibrary.OnlineStoreTemplates.OnlineStoreTemplate

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:current_section, :scrobble_rules)
     |> stream(:templates, OnlineStoreTemplates.list_templates())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Online Store Template")
    |> assign(:template, OnlineStoreTemplates.get_template!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Online Store Template")
    |> assign(:template, %OnlineStoreTemplate{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Online Store Templates")
    |> assign(:template, nil)
  end

  @impl true
  def handle_info(
        {MusicLibraryWeb.OnlineStoreTemplateLive.FormComponent, {:saved, template}},
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
