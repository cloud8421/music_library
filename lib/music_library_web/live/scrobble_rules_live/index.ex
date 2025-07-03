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

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, gettext("Edit Scrobble Rule"))
    |> assign(:scrobble_rule, ScrobbleRules.get_scrobble_rule!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, gettext("New Scrobble Rule"))
    |> stream(:scrobble_rules, ScrobbleRules.list_scrobble_rules())
    |> assign(:scrobble_rule, %ScrobbleRule{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, gettext("Scrobble Rules"))
    |> assign(:scrobble_rule, nil)
    |> stream(:scrobble_rules, ScrobbleRules.list_scrobble_rules())
  end

  @impl true
  def handle_info(
        {MusicLibraryWeb.ScrobbleRulesLive.FormComponent, {:saved, scrobble_rule}},
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
        {:noreply, put_flash(socket, :info, message)}

      {:error, reason} ->
        message = gettext("Error applying rule: %{reason}", reason: reason)
        {:noreply, put_flash(socket, :error, message)}
    end
  end

  @impl true
  def handle_event("apply_all_rules", _params, socket) do
    case ScrobbleRules.apply_all_rules() do
      {:ok, results} ->
        total_updated =
          results
          |> Enum.filter(fn {status, _} -> status == :ok end)
          |> Enum.map(fn {:ok, {_, _, count}} -> count end)
          |> Enum.sum()

        message =
          gettext("All rules applied successfully. Updated %{count} tracks total.",
            count: total_updated
          )

        {:noreply, put_flash(socket, :info, message)}

      {:error, reason} ->
        message = gettext("Error applying rules: %{reason}", reason: reason)
        {:noreply, put_flash(socket, :error, message)}
    end
  end

  defp rule_type_badge(type) do
    case type do
      "album" -> "Album"
      "artist" -> "Artist"
      _ -> type
    end
  end

  defp enabled_badge(enabled) do
    if enabled do
      "Enabled"
    else
      "Disabled"
    end
  end

  defp enabled_badge_class(enabled) do
    if enabled do
      "text-green-800 bg-green-100 dark:bg-green-900 dark:text-green-300"
    else
      "text-red-800 bg-red-100 dark:bg-red-900 dark:text-red-300"
    end
  end

  defp type_badge_class(type) do
    case type do
      "album" -> "text-blue-800 bg-blue-100 dark:bg-blue-900 dark:text-blue-300"
      "artist" -> "text-purple-800 bg-purple-100 dark:bg-purple-900 dark:text-purple-300"
      _ -> "text-gray-800 bg-gray-100 dark:bg-gray-900 dark:text-gray-300"
    end
  end
end
