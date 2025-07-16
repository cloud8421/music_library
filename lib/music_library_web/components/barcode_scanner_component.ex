defmodule MusicLibraryWeb.BarcodeScannerComponent do
  use MusicLibraryWeb, :live_component

  alias MusicBrainz.ReleaseGroupSearchResult
  alias MusicLibrary.BarcodeScan
  alias MusicLibrary.Records
  alias MusicLibraryWeb.RecordComponents

  require Logger

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:camera, :pending)
     |> assign(:scan_results, [])}
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
      <div class="mt-4">
        <.camera_button camera={@camera} />
        <video :if={!(@camera == :denied)} class="w-full hidden h-96" id="camera-preview" playsinline />
      </div>

      <ul class="divide-y divide-zinc-100 dark:divide-slate-300/30 mt-5">
        <li
          :for={scan_result <- @scan_results}
          id={scan_result.number}
          class="flex justify-between gap-x-6 py-5"
          phx-mounted={
            JS.transition(
              {"first:ease-in duration-300", "first:opacity-0 first:p-0 first:h-0",
               "first:opacity-100"},
              time: 300
            )
          }
        >
          <.scan_result scan_result={scan_result} />
        </li>
      </ul>

      <div class="mt-4 flex justify-center">
        <.button
          variant="solid"
          disabled={length(@scan_results) == 0}
          phx-disable-with={gettext("Adding...")}
          phx-click={JS.push("import_releases", target: "#barcode-scanner")}
        >
          {gettext("Add releases")}
        </.button>
      </div>
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
      class="relative block w-full h-96 rounded-lg border-2 border-dashed border-zinc-300 p-12 text-center hover:border-zinc-400 outline-hidden"
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

  attr :scan_result, BarcodeScan.Result, required: true

  defp scan_result(assigns) do
    ~H"""
    <.barcode_not_found :if={@scan_result.status == :not_found} number={@scan_result.number} />
    <.release
      :if={@scan_result.status != :not_found}
      release={@scan_result.release}
      record_id={@scan_result.record_id}
      status={@scan_result.status}
    />
    """
  end

  attr :number, :string, required: true

  defp barcode_not_found(assigns) do
    ~H"""
    <div class="w-full bg-red-50 dark:bg-red-950 p-4">
      <h1 class="text-sm leading-6 text-zinc-700 dark:text-zinc-400">
        {gettext("Barcode not found")}
      </h1>
      <h2 class="mt-1 flex font-semibold text-sm sm:text-base leading-5 text-zinc-700 dark:text-zinc-300 text-wrap">
        {@number}
      </h2>
    </div>
    """
  end

  attr :release, MusicBrainz.ReleaseSearchResult, required: true
  attr :record_id, :string
  attr :status, :atom, required: true, values: [:collected, :wishlisted, :new]

  defp release(assigns) do
    ~H"""
    <div class="flex items-center justify-between w-full">
      <img
        class="w-16 md:w-20 flex-none rounded-lg mr-4"
        alt={@release.release_group.title}
        src={ReleaseGroupSearchResult.thumb_url(@release.release_group)}
        onerror={"this.src = '" <> ~p"/images/cover-not-found.png" <> "';"}
      />
      <div class="min-w-0 flex-auto">
        <h1 class="text-sm leading-6 text-zinc-700 dark:text-zinc-400">
          {@release.artists}
        </h1>
        <h2 class="mt-1 flex font-semibold text-sm sm:text-base leading-5 text-zinc-700 dark:text-zinc-300 text-wrap">
          {@release.title}
        </h2>
        <p class="mt-1 text-xs leading-5 text-zinc-500 dark:text-zinc-400">
          {release_format_label(@release)} · {Records.Record.format_release_date(@release.date)} · {RecordComponents.type_label(
            @release.release_group.type
          )}
        </p>
      </div>
      <.badge :if={@status == :new}>
        {gettext("New")}
      </.badge>
      <.link :if={@status == :wishlisted} navigate={~p"/wishlist/#{@record_id}"}>
        <.badge color="yellow">
          {gettext("Wishlisted")}
        </.badge>
      </.link>
      <.link :if={@status == :collected} navigate={~p"/collection/#{@record_id}"}>
        <.badge color="green">
          {gettext("Collected")}
        </.badge>
      </.link>
    </div>
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

  def handle_event("import_releases", _params, socket) do
    current_time = DateTime.utc_now()

    socket =
      case BarcodeScan.import_results(socket.assigns.scan_results, current_time) do
        [] ->
          put_toast(socket, :info, gettext("Records imported successfully"))

        errors ->
          errors_summary =
            Enum.map_join(errors, "\n", fn {number, reason} ->
              "#{number}: #{inspect(reason)}"
            end)

          put_toast(
            socket,
            :error,
            gettext("Some records could not be imported: %{summary}", summary: errors_summary)
          )
      end

    qs = %{order: :purchase}

    {:noreply,
     socket
     |> assign(:scan_results, [])
     |> push_patch(to: ~p"/collection?#{qs}")}
  end

  defp release_format_label(release) do
    release
    |> MusicBrainz.ReleaseSearchResult.format()
    |> RecordComponents.format_label()
  end
end
