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
     |> assign(:releases, [])}
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
        <p>{@camera}</p>
        <button
          :if={@camera == :pending}
          type="button"
          phx-click={JS.dispatch("camera_request", to: "#barcode-scanner")}
          class="relative block w-full rounded-lg border-2 border-dashed border-zinc-300 p-12 text-center hover:border-zinc-400 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2"
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
        <video class="w-full" id="camera-preview"></video>
      </div>
      <ul>
        <li :for={release <- assigns.releases}>
          <span>{release.id}</span>
          <span>{release.barcode}</span>
          <span>{release.title}</span>
        </li>
      </ul>
    </div>
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
