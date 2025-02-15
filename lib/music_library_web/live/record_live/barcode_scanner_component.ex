defmodule MusicLibraryWeb.RecordLive.BarcodeScannerComponent do
  use MusicLibraryWeb, :live_component

  alias MusicLibrary.Records

  require Logger

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:camera, :pending)
     |> assign(:barcodes, MapSet.new())
     |> assign(:releases, [
       %MusicBrainz.ReleaseSearchResult{
         id: "dc393148-be34-4056-be66-b2b95905c5c1",
         title: "Equally Cursed and Blessed",
         release_group: %{
           id: "c35fc446-65cc-3645-939b-1b3782e60639",
           type: :album,
           title: "Equally Cursed and Blessed"
         },
         artists: "Catatonia",
         date: "1999-04-12",
         barcode: "639842709422",
         media: [%{format: "CD", disc_count: 5, track_count: 11}]
       }
     ])}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="barcode-scanner" phx-hook="BarcodeScanner" phx-target={@myself}>
      <header>
        <h1 class="text-sm font-medium leading-6 text-zinc-700 dark:text-zinc-400">
          {gettext("Scan one or more barcodes")}
        </h1>
      </header>
      <div>
        <button
          :if={!(@camera == :allowed)}
          id="camera-button"
          type="button"
          phx-click={
            JS.show(to: "#camera-preview")
            |> JS.dispatch("camera_request", to: "#barcode-scanner")
            |> JS.hide(to: "#camera-button")
          }
          class="relative block w-full h-96 rounded-lg border-2 border-dashed border-zinc-300 p-12 text-center hover:border-zinc-400 focus:outline-none focus:ring-2 focus:ring-zinc-500 focus:ring-offset-2"
        >
          <svg
            class="mx-auto size-12 text-zinc-400"
            stroke="currentColor"
            fill="none"
            viewBox="0 0 24 24"
            aria-hidden="true"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="m15.75 10.5 4.72-4.72a.75.75 0 0 1 1.28.53v11.38a.75.75 0 0 1-1.28.53l-4.72-4.72M4.5 18.75h9a2.25 2.25 0 0 0 2.25-2.25v-9a2.25 2.25 0 0 0-2.25-2.25h-9A2.25 2.25 0 0 0 2.25 7.5v9a2.25 2.25 0 0 0 2.25 2.25Z"
            />
          </svg>
          <span class="mt-2 block text-sm font-semibold text-zinc-900">{gettext("Open camera")}</span>
        </button>
        <video :if={!(@camera == :denied)} class="w-full hidden" id="camera-preview"></video>
      </div>
      <ul class="divide-y divide-zinc-100 dark:divide-slate-300/30 mt-5">
        <.result :for={release <- assigns.releases} id={release.id} release={release} />
      </ul>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :release, MusicBrainz.ReleaseSearchResult, required: true

  defp result(assigns) do
    ~H"""
    <li id={@id} class="flex justify-between gap-x-6 py-5 hover:bg-zinc-50 dark:hover:bg-zinc-700">
      <div class="shrink-0 flex items-center justify-between w-full px-4">
        <div class="min-w-0 flex-auto">
          <h1 class="text-sm leading-6 text-zinc-700 dark:text-zinc-400">
            {@release.artists}
          </h1>
          <h2 class="mt-1 flex font-semibold text-sm sm:text-base leading-5 text-zinc-700 dark:text-zinc-300 text-wrap">
            {@release.title}
          </h2>
          <p class="mt-1 text-xs leading-5 text-zinc-500 dark:text-zinc-400">
            {Records.Record.format_release(@release.date)} · {@release.barcode}
          </p>
        </div>
      </div>
    </li>
    """
  end

  @impl true
  def handle_event("camera_allowed", _params, socket) do
    Logger.debug(fn -> "Camera access allowed" end)
    {:noreply, assign(socket, camera: :allowed)}
  end

  def handle_event("camera_denied", _params, socket) do
    Logger.debug(fn -> "Camera access denied" end)
    {:noreply, assign(socket, camera: :denied)}
  end

  def handle_event("barcode_scanned", %{"number" => number}, socket) do
    Logger.debug(fn -> "Scanned barcode #{number}" end)

    {:ok, releases} =
      Records.search_release_by_barcode(number)

    socket =
      socket
      |> assign(barcodes: MapSet.put(socket.assigns.barcodes, number))
      |> assign(:releases, releases ++ socket.assigns.releases)

    {:noreply, socket}
  end
end
