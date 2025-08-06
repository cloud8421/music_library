defmodule MusicLibraryWeb.ScrobbleRulesLive.Index do
  use MusicLibraryWeb, :live_view

  alias MusicLibrary.ScrobbleRules
  alias MusicLibrary.ScrobbleRules.ScrobbleRule

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :current_section, :scrobble_rules)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id} = params) do
    socket
    |> apply_fallback_index(params)
    |> assign(:page_title, gettext("Edit Scrobble Rule"))
    |> assign(:scrobble_rule, ScrobbleRules.get_scrobble_rule!(id))
  end

  defp apply_action(socket, :new, params) do
    socket
    |> apply_fallback_index(params)
    |> assign(:page_title, gettext("New Scrobble Rule"))
    |> assign(:scrobble_rule, %ScrobbleRule{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, gettext("Scrobble Rules"))
    |> assign(:scrobble_rule, nil)
    |> stream(:scrobble_rules, ScrobbleRules.list_scrobble_rules(), reset: true)
  end

  def apply_fallback_index(socket, params) do
    if get_in(socket.assigns, [:streams, :scrobble_rules]) == nil do
      socket
      |> apply_action(:index, params)
    else
      socket
    end
  end

  @impl true
  def handle_info(
        {MusicLibraryWeb.ScrobbleRulesLive.FormComponent, {:created, scrobble_rule}},
        socket
      ) do
    {:noreply, stream_insert(socket, :scrobble_rules, scrobble_rule, at: 0)}
  end

  def handle_info(
        {MusicLibraryWeb.ScrobbleRulesLive.FormComponent, {:updated, scrobble_rule}},
        socket
      ) do
    {:noreply, stream_insert(socket, :scrobble_rules, scrobble_rule)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    scrobble_rule = ScrobbleRules.get_scrobble_rule!(id)
    {:ok, _} = ScrobbleRules.delete_scrobble_rule(scrobble_rule)

    {:noreply, stream_delete(socket, :scrobble_rules, scrobble_rule)}
  end

  @impl true
  def handle_event("toggle_enabled", %{"id" => id}, socket) do
    scrobble_rule = ScrobbleRules.get_scrobble_rule!(id)

    {:ok, updated_rule} =
      ScrobbleRules.update_scrobble_rule(scrobble_rule, %{enabled: !scrobble_rule.enabled})

    {:noreply, stream_insert(socket, :scrobble_rules, updated_rule)}
  end

  @impl true
  def handle_event("apply_rule", %{"id" => id}, socket) do
    scrobble_rule = ScrobbleRules.get_scrobble_rule!(id)

    case ScrobbleRules.apply_rule(scrobble_rule) do
      {:ok, count} ->
        message = gettext("Rule applied successfully. Updated %{count} tracks.", count: count)
        {:noreply, put_toast(socket, :info, message)}

      {:error, reason} ->
        message = gettext("Error applying rule: %{reason}", reason: reason)
        {:noreply, put_toast(socket, :error, message)}
    end
  end

  @impl true
  def handle_event("apply_all_rules", _params, socket) do
    results = ScrobbleRules.apply_all_rules()

    total_updated =
      results
      |> Enum.filter(fn {status, _} -> status == :ok end)
      |> Enum.map(fn {:ok, {_, _, count}} -> count end)
      |> Enum.sum()

    message =
      gettext("All rules applied successfully. Updated %{count} tracks total.",
        count: total_updated
      )

    {:noreply, put_toast(socket, :info, message)}
  end

  attr :type, :atom, required: true, values: [:album, :artist]

  defp type_badge(assigns) do
    ~H"""
    <.badge :if={@type == :album} color="red">{gettext("Album")}</.badge>
    <.badge :if={@type == :artist} color="cyan">{gettext("Artist")}</.badge>
    """
  end

  attr :enabled, :boolean, required: true

  defp status_badge(assigns) do
    ~H"""
    <.badge :if={@enabled} color="green">{gettext("Enabled")}</.badge>
    <.badge :if={!@enabled} color="yellow">{gettext("Disabled")}</.badge>
    """
  end
end
