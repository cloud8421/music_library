defmodule MusicLibraryWeb.Components.BarcodeScanner do
  use MusicLibraryWeb, :live_component

  import MusicLibraryWeb.CartComponents, only: [cart_sidebar: 1]

  alias MusicBrainz.ReleaseGroupSearchResult
  alias MusicLibrary.BarcodeScan
  alias MusicLibrary.Records
  alias MusicLibraryWeb.ErrorMessages
  alias MusicLibraryWeb.RecordComponents

  require Logger

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:camera, :pending)
     |> assign(:scan_results, [])
     |> assign(:cart_expanded?, true)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="barcode-scanner" phx-hook=".BarcodeScanner" phx-target={@myself}>
      <div class="grid grid-cols-1 md:grid-cols-5">
        <section class="md:col-span-3 md:p-4 md:border-r md:border-zinc-200 md:dark:border-zinc-800">
          <header>
            <h1 class="text-sm/6 font-medium text-zinc-700 dark:text-zinc-400">
              {gettext("Scan one or more barcodes")}
            </h1>
          </header>
          <div class="mt-4">
            <.camera_button camera={@camera} />
            <video
              :if={!(@camera == :denied)}
              class="hidden h-96 w-full"
              id="camera-preview"
              playsinline
            />
          </div>
        </section>

        <.cart_sidebar
          count={length(@scan_results)}
          expanded?={@cart_expanded?}
          on_clear="clear_results"
          on_toggle="toggle_cart"
          target={@myself}
          empty_heading={gettext("Your cart is empty")}
          empty_subtext={gettext("Scan barcodes to add records.")}
        >
          <:empty_icon>
            <.barcode_icon class="size-8 text-zinc-400" />
          </:empty_icon>
          <:action>
            <.button
              variant="solid"
              phx-disable-with={gettext("Adding...")}
              phx-click={JS.push("import_releases", target: "#barcode-scanner")}
              class="w-full"
            >
              {ngettext(
                "Add %{count} release",
                "Add %{count} releases",
                length(@scan_results),
                count: length(@scan_results)
              )}
            </.button>
          </:action>
          <li
            :for={result <- @scan_results}
            id={"cart-item-#{result.number}"}
            class="flex gap-3 px-4 py-3"
            phx-mounted={
              JS.transition(
                {"first:ease-in duration-300", "first:opacity-0 first:p-0 first:h-0",
                 "first:opacity-100"},
                time: 300
              )
            }
          >
            <.cart_item result={result} myself={@myself} />
          </li>
        </.cart_sidebar>
      </div>

      <script :type={Phoenix.LiveView.ColocatedHook} name=".BarcodeScanner">
        import { BarcodeDetector } from "barcode-detector/ponyfill";

        const barcodeReaderSetup = async function () {
          const supportedFormats = await BarcodeDetector.getSupportedFormats();

          return new BarcodeDetector({
            // make sure the formats are supported
            formats: supportedFormats,
          });
        };

        export default {
          async mounted() {
            const detectedBarcodes = new Set([]);
            const barcodeDetector = await barcodeReaderSetup();
            this.detectedBarcodes = detectedBarcodes;
            this.cameraPreview = this.el.querySelector("#camera-preview");
            const constraints = {
              audio: false,
              video: {
                width: 800,
                height: 600,
                facingMode: {
                  ideal: "environment",
                },
              },
            };
            this.handleEvent("remove_barcode", ({ number }) => {
              detectedBarcodes.delete(number);
            });
            this.handleEvent("clear_barcodes", () => {
              detectedBarcodes.clear();
            });
            this.el.addEventListener("camera_request", () => {
              navigator.mediaDevices
                .getUserMedia(constraints)
                .then((mediaStream) => {
                  console.debug("Camera access allowed");
                  this.pushEventTo(this.el, "camera_allowed", {});
                  this.cameraPreview.srcObject = mediaStream;
                  this.cameraPreview.onloadedmetadata = () => {
                    this.cameraPreview.play();
                    this.scanInterval = window.setInterval(async () => {
                      const barcodes = await barcodeDetector.detect(this.cameraPreview);
                      if (barcodes.length <= 0) return;

                      barcodes.forEach((barcode) => {
                        if (!detectedBarcodes.has(barcode.rawValue)) {
                          this.pushEventTo(this.el, "barcode_scanned", {
                            number: barcode.rawValue,
                          });
                          detectedBarcodes.add(barcode.rawValue);
                        }
                      });
                    }, 500);
                  };
                })
                .catch((err) => {
                  console.error(`${err.name}: ${err.message}`);
                  this.pushEventTo(this.el, "camera_denied", {});
                });
            });
          },
          teardownCamera() {
            if (this.cameraPreview && this.cameraPreview.srcObject) {
              this.cameraPreview.srcObject.getTracks().forEach((track) => track.stop());
              this.cameraPreview.srcObject = null;
            }
            if (this.scanInterval) {
              window.clearInterval(this.scanInterval);
              this.scanInterval = null;
            }
          },
          disconnected() {
            // Stop the camera while we're disconnected so that on reconnect
            // the server's :pending state and our DOM agree (button visible,
            // preview hidden) instead of leaving a live stream behind.
            this.teardownCamera();
            if (this.cameraPreview) {
              this.cameraPreview.classList.add("hidden");
            }
            const button = this.el.querySelector("#camera-button");
            if (button) {
              button.style.display = "";
            }
          },
          destroyed() {
            this.teardownCamera();
          },
        };
      </script>
    </div>
    """
  end

  attr :camera, :atom, required: true, values: [:pending, :allowed, :denied]

  def camera_button(assigns) do
    ~H"""
    <button
      :if={!(@camera == :allowed)}
      id="camera-button"
      type="button"
      phx-click={
        JS.show(to: "#camera-preview")
        |> JS.dispatch("camera_request", to: "#barcode-scanner")
        |> JS.hide(to: "#camera-button")
      }
      class="relative block h-96 w-full rounded-lg border-2 border-dashed border-zinc-300 p-12 text-center outline-hidden hover:border-zinc-400"
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
      <span class="mt-2 block text-sm font-semibold text-zinc-900 dark:text-zinc-400">
        {gettext("Open camera")}
      </span>
    </button>
    """
  end

  attr :class, :string, required: true

  def barcode_icon(assigns) do
    ~H"""
    <svg
      class={@class}
      aria-hidden="true"
      data-slot="icon"
      xmlns="http://www.w3.org/2000/svg"
      xmlns:xlink="http://www.w3.org/1999/xlink"
      version="1.1"
      width="16"
      height="16"
      viewBox="0 0 256 256"
      xml:space="preserve"
    >
      <g
        style="stroke: none; stroke-width: 0; stroke-dasharray: none; stroke-linecap: butt; stroke-linejoin: miter; stroke-miterlimit: 10; fill-rule: nonzero; opacity: 1;"
        transform="translate(1.4065934065934016 1.4065934065934016) scale(2.81 2.81)"
      >
        <polygon
          points="90,79.14 56.12,79.14 56.12,73.14 84,73.14 84,54.67 90,54.67 "
          style="stroke: none; stroke-width: 1; stroke-dasharray: none; stroke-linecap: butt; stroke-linejoin: miter; stroke-miterlimit: 10; fill-rule: nonzero; opacity: 1;"
          transform="  matrix(1 0 0 1 0 0) "
        />
        <polygon
          points="33.88,79.14 0,79.14 0,54.67 6,54.67 6,73.14 33.88,73.14 "
          style="stroke: none; stroke-width: 1; stroke-dasharray: none; stroke-linecap: butt; stroke-linejoin: miter; stroke-miterlimit: 10; fill-rule: nonzero; opacity: 1;"
          transform="  matrix(1 0 0 1 0 0) "
        />
        <polygon
          points="6,35.33 0,35.33 0,10.86 33.88,10.86 33.88,16.86 6,16.86 "
          style="stroke: none; stroke-width: 1; stroke-dasharray: none; stroke-linecap: butt; stroke-linejoin: miter; stroke-miterlimit: 10; fill-rule: nonzero; opacity: 1;"
          transform="  matrix(1 0 0 1 0 0) "
        />
        <polygon
          points="90,35.33 84,35.33 84,16.86 56.12,16.86 56.12,10.86 90,10.86 "
          style="stroke: none; stroke-width: 1; stroke-dasharray: none; stroke-linecap: butt; stroke-linejoin: miter; stroke-miterlimit: 10; fill-rule: nonzero; opacity: 1;"
          transform="  matrix(1 0 0 1 0 0) "
        />
        <rect
          x="36.27"
          y="26.31"
          rx="0"
          ry="0"
          width="6"
          height="37.39"
          style="stroke: none; stroke-width: 1; stroke-dasharray: none; stroke-linecap: butt; stroke-linejoin: miter; stroke-miterlimit: 10; fill-rule: nonzero; opacity: 1;"
          transform=" matrix(1 0 0 1 0 0) "
        />
        <rect
          x="13.36"
          y="26.31"
          rx="0"
          ry="0"
          width="6"
          height="37.39"
          style="stroke: none; stroke-width: 1; stroke-dasharray: none; stroke-linecap: butt; stroke-linejoin: miter; stroke-miterlimit: 10; fill-rule: nonzero; opacity: 1;"
          transform=" matrix(1 0 0 1 0 0) "
        />
        <rect
          x="59.18"
          y="26.31"
          rx="0"
          ry="0"
          width="6"
          height="24.02"
          style="stroke: none; stroke-width: 1; stroke-dasharray: none; stroke-linecap: butt; stroke-linejoin: miter; stroke-miterlimit: 10; fill-rule: nonzero; opacity: 1;"
          transform=" matrix(1 0 0 1 0 0) "
        />
        <rect
          x="59.18"
          y="56.85"
          rx="0"
          ry="0"
          width="6"
          height="6.84"
          style="stroke: none; stroke-width: 1; stroke-dasharray: none; stroke-linecap: butt; stroke-linejoin: miter; stroke-miterlimit: 10; fill-rule: nonzero; opacity: 1;"
          transform=" matrix(1 0 0 1 0 0) "
        />
        <rect
          x="24.82"
          y="26.31"
          rx="0"
          ry="0"
          width="6"
          height="24.02"
          style="stroke: none; stroke-width: 1; stroke-dasharray: none; stroke-linecap: butt; stroke-linejoin: miter; stroke-miterlimit: 10; fill-rule: nonzero; opacity: 1;"
          transform=" matrix(1 0 0 1 0 0) "
        />
        <rect
          x="24.82"
          y="56.85"
          rx="0"
          ry="0"
          width="6"
          height="6.84"
          style="stroke: none; stroke-width: 1; stroke-dasharray: none; stroke-linecap: butt; stroke-linejoin: miter; stroke-miterlimit: 10; fill-rule: nonzero; opacity: 1;"
          transform=" matrix(1 0 0 1 0 0) "
        />
        <rect
          x="70.64"
          y="26.31"
          rx="0"
          ry="0"
          width="6"
          height="24.02"
          style="stroke: none; stroke-width: 1; stroke-dasharray: none; stroke-linecap: butt; stroke-linejoin: miter; stroke-miterlimit: 10; fill-rule: nonzero; opacity: 1;"
          transform=" matrix(1 0 0 1 0 0) "
        />
        <rect
          x="70.64"
          y="56.85"
          rx="0"
          ry="0"
          width="6"
          height="6.84"
          style="stroke: none; stroke-width: 1; stroke-dasharray: none; stroke-linecap: butt; stroke-linejoin: miter; stroke-miterlimit: 10; fill-rule: nonzero; opacity: 1;"
          transform=" matrix(1 0 0 1 0 0) "
        />
        <rect
          x="47.73"
          y="26.31"
          rx="0"
          ry="0"
          width="6"
          height="37.39"
          style="stroke: none; stroke-width: 1; stroke-dasharray: none; stroke-linecap: butt; stroke-linejoin: miter; stroke-miterlimit: 10; fill-rule: nonzero; opacity: 1;"
          transform=" matrix(1 0 0 1 0 0) "
        />
      </g>
    </svg>
    """
  end

  attr :result, BarcodeScan.Result, required: true
  attr :myself, :any, required: true

  defp cart_item(%{result: %{status: :not_found}} = assigns) do
    ~H"""
    <.barcode_icon class="w-12 h-12 flex-none rounded-md p-2 bg-red-50 text-red-400 dark:bg-red-950" />
    <div class="min-w-0 flex-1">
      <p class="truncate text-xs text-zinc-500 dark:text-zinc-400">
        {@result.number}
      </p>
      <p class="truncate text-sm font-medium text-zinc-700 dark:text-zinc-300">
        {gettext("Barcode not found")}
      </p>
      <div class="mt-1 flex items-center gap-2">
        <.status_badge status={:not_found} />
        <button
          type="button"
          phx-click="remove_result"
          phx-value-number={@result.number}
          phx-target={@myself}
          class="text-xs text-zinc-500 hover:text-red-600 dark:hover:text-red-400"
        >
          {gettext("Remove")}
        </button>
      </div>
    </div>
    """
  end

  defp cart_item(assigns) do
    ~H"""
    <img
      class="w-12 h-12 rounded-md flex-none object-cover"
      alt={@result.release.release_group.title}
      src={ReleaseGroupSearchResult.thumb_url(@result.release.release_group)}
      onerror={"this.src = '" <> ~p"/images/cover-not-found.png" <> "';"}
    />
    <div class="min-w-0 flex-1">
      <p class="truncate text-xs text-zinc-500 dark:text-zinc-400">
        {@result.release.artists}
      </p>
      <p class="truncate text-sm font-medium text-zinc-700 dark:text-zinc-300">
        {@result.release.title}
      </p>
      <p class="truncate text-xs/5 text-zinc-500 dark:text-zinc-400">
        {release_format_label(@result.release)} · {Records.Record.format_release_date(
          @result.release.date
        )} · {RecordComponents.type_label(@result.release.release_group.type)}
      </p>
      <div class="mt-1 flex items-center gap-2">
        <.status_badge status={@result.status} record_id={@result.record_id} />
        <button
          type="button"
          phx-click="remove_result"
          phx-value-number={@result.number}
          phx-target={@myself}
          class="text-xs text-zinc-500 hover:text-red-600 dark:hover:text-red-400"
        >
          {gettext("Remove")}
        </button>
      </div>
    </div>
    """
  end

  attr :status, :atom, required: true, values: [:new, :wishlisted, :collected, :not_found]
  attr :record_id, :string, default: nil

  defp status_badge(%{status: :new} = assigns) do
    ~H"""
    <.badge class="block">{gettext("New")}</.badge>
    """
  end

  defp status_badge(%{status: :wishlisted} = assigns) do
    ~H"""
    <.link navigate={~p"/wishlist/#{@record_id}"}>
      <.badge size="xs" color="warning" class="block">{gettext("Wishlisted")}</.badge>
    </.link>
    """
  end

  defp status_badge(%{status: :collected} = assigns) do
    ~H"""
    <.link navigate={~p"/collection/#{@record_id}"}>
      <.badge size="xs" color="success" class="block">{gettext("Collected")}</.badge>
    </.link>
    """
  end

  defp status_badge(%{status: :not_found} = assigns) do
    ~H"""
    <.badge size="xs" color="danger" class="block">{gettext("Not found")}</.badge>
    """
  end

  @impl true
  def handle_event("camera_allowed", _params, socket) do
    {:noreply, assign(socket, camera: :allowed)}
  end

  def handle_event("camera_denied", _params, socket) do
    {:noreply, assign(socket, camera: :denied)}
  end

  def handle_event("barcode_scanned", %{"number" => number}, socket) do
    socket =
      case BarcodeScan.scan(number) do
        {:ok, scan_result} ->
          assign(socket, :scan_results, [scan_result | socket.assigns.scan_results])

        {:error, reason} ->
          Logger.error(fn ->
            "Failed to search release for barcode #{number}: #{inspect(reason)}"
          end)

          put_toast(
            socket,
            :error,
            gettext("Failed to search release for barcode %{number}", number: number)
          )
      end

    {:noreply, socket}
  end

  def handle_event("remove_result", %{"number" => number}, socket) do
    scan_results = Enum.reject(socket.assigns.scan_results, &(&1.number == number))

    {:noreply,
     socket
     |> assign(:scan_results, scan_results)
     |> push_event("remove_barcode", %{number: number})}
  end

  def handle_event("clear_results", _params, socket) do
    {:noreply,
     socket
     |> assign(:scan_results, [])
     |> push_event("clear_barcodes", %{})}
  end

  def handle_event("toggle_cart", _params, socket) do
    {:noreply, assign(socket, :cart_expanded?, not socket.assigns.cart_expanded?)}
  end

  def handle_event("import_releases", _params, socket) do
    current_time = DateTime.utc_now()
    scan_results = socket.assigns.scan_results

    socket =
      if BarcodeScan.should_import_async?(scan_results) do
        {:ok, sync_errors, async_count} =
          BarcodeScan.import_results_async(scan_results, current_time)

        socket
        |> maybe_toast_errors(sync_errors)
        |> put_toast(
          :info,
          ngettext(
            "Importing %{count} record in the background...",
            "Importing %{count} records in the background...",
            async_count,
            count: async_count
          )
        )
      else
        case BarcodeScan.import_results(scan_results, current_time) do
          [] ->
            put_toast(socket, :info, gettext("Records imported successfully"))

          errors ->
            maybe_toast_errors(socket, errors)
        end
      end

    qs = %{order: :purchase}

    {:noreply,
     socket
     |> assign(:scan_results, [])
     |> push_patch(to: ~p"/collection?#{qs}")}
  end

  defp maybe_toast_errors(socket, []), do: socket

  defp maybe_toast_errors(socket, errors) do
    errors_summary =
      Enum.map_join(errors, "\n", fn {number, reason} ->
        "#{number}: #{ErrorMessages.friendly_message(reason)}"
      end)

    put_toast(
      socket,
      :error,
      gettext("Some records could not be imported: %{summary}", summary: errors_summary)
    )
  end

  defp release_format_label(release) do
    release
    |> MusicBrainz.ReleaseSearchResult.format()
    |> RecordComponents.format_label()
  end
end
