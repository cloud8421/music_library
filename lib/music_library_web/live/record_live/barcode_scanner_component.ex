defmodule MusicLibraryWeb.RecordLive.BarcodeScannerComponent do
  use MusicLibraryWeb, :live_component

  require Logger

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <h1>Barcode Scan</h1>
      <video id="barcode-scan" phx-hook="BarcodeScanner"></video>
    </div>
    """
  end

  @impl true
  def handle_event("camera:allowed", _params, socket) do
    Logger.debug(fn -> "Camera access allowed" end)
    {:noreply, assign(socket, camera: :allowed)}
  end

  def handle_event("camera:denied", _params, socket) do
    Logger.debug(fn -> "Camera access denied" end)
    {:noreply, assign(socket, camera: :denied)}
  end
end
