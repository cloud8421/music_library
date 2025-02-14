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
        <video id="camera-preview"></video>
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
