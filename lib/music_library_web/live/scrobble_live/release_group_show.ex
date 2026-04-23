defmodule MusicLibraryWeb.ScrobbleLive.ReleaseGroupShow do
  @moduledoc false
  use MusicLibraryWeb, :live_view

  require Logger

  import MusicLibraryWeb.RecordComponents, only: [type_label: 1, country_label: 1]

  alias MusicBrainz.{Release, ReleaseGroupSearchResult}
  alias MusicLibrary.Records
  alias MusicLibraryWeb.ErrorMessages
  alias Phoenix.LiveView.AsyncResult

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_section={@current_section}
      socket={@socket}
      toasts_sync={assigns[:toasts_sync]}
    >
      <div class="my-4">
        <.button variant="ghost" size="sm" navigate={~p"/scrobble"}>
          <.icon name="hero-arrow-left" class="icon" aria-hidden="true" data-slot="icon" />
          {gettext("Back to search")}
        </.button>
      </div>

      <.async_result :let={data} assign={@release_group_data}>
        <:loading>
          <div class="py-8 text-center">
            <.loading class="mx-auto size-8 text-zinc-400" />
          </div>
        </:loading>
        <:failed :let={_failure}>
          <div class="py-8 text-center text-zinc-500">
            {gettext("Could not load release group")}
          </div>
        </:failed>

        <div class="flex items-start gap-4">
          <img
            class="w-32 flex-none rounded-lg drop-shadow-sm"
            alt={data.release_group.title}
            src={ReleaseGroupSearchResult.thumb_url(data.release_group)}
            onerror={"this.src = '" <> ~p"/images/cover-not-found.png" <> "';"}
          />
          <div class="min-w-0 flex-auto">
            <h1 class="text-xl font-semibold text-zinc-900 dark:text-zinc-100">
              {data.release_group.title}
            </h1>
            <p class="mt-1 text-sm text-zinc-500 dark:text-zinc-400">
              {data.release_group.artists}
            </p>
            <div class="mt-2 flex flex-wrap items-center gap-2 text-xs text-zinc-500 dark:text-zinc-400">
              <.badge variant="soft" size="xs">{type_label(data.release_group.type)}</.badge>
              <span>{Records.Record.format_release_date(data.release_group.release_date)}</span>
              <span>·</span>
              <span>
                {ngettext("%{count} release", "%{count} releases", length(data.releases),
                  count: length(data.releases)
                )}
              </span>
            </div>
          </div>
        </div>

        <ul class="mt-6 divide-y divide-zinc-100 dark:divide-slate-300/30">
          <li :for={release <- data.releases}>
            <.link
              navigate={~p"/scrobble/#{@rg_id}/releases/#{release.id}"}
              class="flex items-center gap-x-4 px-4 py-5 transition-colors hover:bg-zinc-100 dark:hover:bg-zinc-700"
            >
              <img
                class="w-20 flex-none rounded-lg"
                alt={release.title}
                src={Release.thumb_url(release)}
                onerror={"this.src = '" <> ~p"/images/cover-not-found.png" <> "';"}
              />
              <div class="min-w-0 flex-auto">
                <p class="font-medium text-zinc-900 dark:text-zinc-100">
                  {release.title}
                </p>
                <div class="mt-1 flex flex-wrap items-center gap-x-2 gap-y-1 text-sm text-zinc-500 dark:text-zinc-400">
                  <span :if={release.date}>{release.date}</span>
                  <span :if={release.country}>{country_label(release.country)}</span>
                  <.badge :if={release.catalog_number} variant="soft" size="xs">
                    {release.catalog_number}
                  </.badge>
                  <span :if={release.media != []}>
                    {ngettext("1 disc", "%{count} discs", Release.media_count(release))}
                  </span>
                </div>
              </div>
            </.link>
          </li>
        </ul>
      </.async_result>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       current_section: :scrobble,
       release_group_data: AsyncResult.loading(),
       rg_id: nil,
       page_title: gettext("Scrobble")
     )}
  end

  @impl true
  def handle_params(%{"rg_id" => rg_id}, _url, socket) do
    {:noreply,
     socket
     |> assign(:rg_id, rg_id)
     |> assign(:release_group_data, AsyncResult.loading())
     |> start_async(:release_group_data, fn -> load(rg_id) end)}
  end

  @impl true
  def handle_async(:release_group_data, {:ok, {:ok, data}}, socket) do
    {:noreply,
     assign(
       socket,
       :release_group_data,
       AsyncResult.ok(socket.assigns.release_group_data, data)
     )}
  end

  def handle_async(:release_group_data, {:ok, {:error, reason}}, socket) do
    {:noreply,
     socket
     |> put_toast(
       :error,
       gettext("Error loading release group") <> ": " <> ErrorMessages.friendly_message(reason)
     )
     |> push_navigate(to: ~p"/scrobble")}
  end

  def handle_async(:release_group_data, {:exit, reason}, socket) do
    Logger.error("Release-group show exited: #{inspect(reason)}")

    {:noreply,
     socket
     |> put_toast(:error, gettext("Error loading release group"))
     |> push_navigate(to: ~p"/scrobble")}
  end

  defp load(rg_id) do
    with {:ok, raw_rg} <- MusicBrainz.get_release_group(rg_id),
         {:ok, release_group} <- parse_release_group(raw_rg),
         {:ok, %{"releases" => raw_releases}} <- MusicBrainz.get_releases(rg_id, limit: 50) do
      releases = Enum.map(raw_releases, &Release.from_api_response/1)
      {:ok, %{release_group: release_group, releases: releases}}
    end
  end

  defp parse_release_group(%{"id" => _, "artist-credit" => _} = raw) do
    {:ok, ReleaseGroupSearchResult.from_api_response(raw)}
  end

  defp parse_release_group(_) do
    {:error, :invalid_release_group_response}
  end
end
