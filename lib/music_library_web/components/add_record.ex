defmodule MusicLibraryWeb.Components.AddRecord do
  @moduledoc """
  Cart-style MusicBrainz import modal.

  Users search MusicBrainz, stage `{release_group, format}` pairs into an ephemeral
  cart, then import them all at once. A single-item cart runs synchronously via
  `start_async`; two or more items enqueue one Oban job per item and close the modal.

  The parent LiveView receives two messages and handles navigation/toasts:
    - `{__MODULE__, {:imported_single, record}}`
    - `{__MODULE__, {:imported_async, count}}`
  """

  use MusicLibraryWeb, :live_component

  import MusicLibraryWeb.RecordComponents, only: [format_label: 1, type_label: 1]

  alias MusicBrainz.ReleaseGroupSearchResult
  alias MusicLibrary.Records
  alias MusicLibrary.Worker.ImportFromMusicbrainzReleaseGroup
  alias MusicLibraryWeb.ErrorMessages

  require Logger

  @batch_size 20
  @default_format :cd

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <div class="grid grid-cols-1 md:grid-cols-5">
        <section class="md:col-span-3 md:p-4 md:border-r md:border-zinc-200 md:dark:border-zinc-800">
          <.simple_form
            for={@form}
            id={:import_form}
            phx-target={@myself}
            phx-change="search"
            phx-submit="search"
          >
            <.input
              id={:mb_query}
              name={:mb_query}
              field={@form[:mb_query]}
              type="search"
              label={gettext("Search for a record")}
              phx-debounce="500"
              autocomplete="off"
              autofocus
            />
          </.simple_form>
          <.alert :if={@error_message} color="danger" hide_close class="mt-4">
            {@error_message}
          </.alert>
          <ul
            id="release-groups"
            phx-viewport-bottom={!@loaded_all_results? && "load-more"}
            phx-target={@myself}
            role="list"
            class={[
              "mt-5 divide-y divide-zinc-100 dark:divide-slate-300/30",
              "max-h-125 overflow-y-auto"
            ]}
          >
            <.result
              :for={release_group <- @release_groups}
              id={"musicbrainz_#{release_group.id}"}
              myself={@myself}
              in_cart?={in_cart?(@cart_pairs, release_group.id)}
              cart_formats={cart_formats(@cart, release_group.id)}
              release_group={release_group}
              icon_name={@icon_name}
            />
          </ul>
          <div
            :if={@release_groups_count == 0}
            id="release-groups-empty"
            class="text-md flex h-64 items-center justify-center text-zinc-500 md:h-64"
          >
            {gettext("No results")}
          </div>
        </section>

        <aside class={[
          "md:col-span-2",
          "border-t md:border-t-0 md:border-l md:border-zinc-200 md:dark:border-zinc-800",
          "flex flex-col"
        ]}>
          <div class="px-4 py-3 flex items-center justify-between border-b border-zinc-200 dark:border-zinc-800">
            <div class="flex items-center gap-2">
              <p class="text-sm font-semibold text-zinc-700 dark:text-zinc-300">
                {gettext("Cart")}
              </p>
              <span class="text-xs text-zinc-500 dark:text-zinc-400">
                {ngettext("%{count} record", "%{count} records", length(@cart), count: length(@cart))}
              </span>
            </div>
            <div class="flex items-center gap-3">
              <button
                :if={@cart != []}
                type="button"
                phx-click="clear_cart"
                phx-target={@myself}
                class="text-xs text-zinc-500 hover:text-zinc-900 dark:hover:text-zinc-100"
              >
                {gettext("Clear all")}
              </button>
              <button
                type="button"
                phx-click="toggle_cart"
                phx-target={@myself}
                class="rounded-md p-1 text-zinc-500 hover:bg-zinc-200 dark:hover:bg-zinc-800 md:hidden"
                aria-label={gettext("Toggle cart")}
              >
                <.icon
                  name={if @cart_expanded?, do: "hero-chevron-down", else: "hero-chevron-up"}
                  class="size-4"
                  aria-hidden="true"
                  data-slot="icon"
                />
              </button>
            </div>
          </div>

          <div class={["md:!block", not @cart_expanded? && "hidden"]}>
            <div
              :if={@cart == []}
              id="cart-empty"
              class="flex flex-col items-center justify-center gap-2 px-6 py-10 text-center"
            >
              <.icon
                name="hero-shopping-bag"
                class="size-8 text-zinc-400"
                aria-hidden="true"
                data-slot="icon"
              />
              <p class="text-sm text-zinc-500 dark:text-zinc-400">
                {gettext("Your cart is empty")}
              </p>
              <p class="text-xs text-zinc-500 dark:text-zinc-400">
                {gettext("Add records from the search results to get started.")}
              </p>
            </div>

            <ul
              :if={@cart != []}
              id="cart-items"
              class="divide-y divide-zinc-200 dark:divide-zinc-800 md:max-h-[calc(100vh-20rem)] overflow-y-auto"
            >
              <li
                :for={item <- @cart}
                id={"cart-item-#{item.cart_item_id}"}
                class="flex gap-3 px-4 py-3"
              >
                <img
                  class="w-12 h-12 rounded-md object-cover"
                  alt={item.title}
                  src={item.thumb_url}
                  onerror={"this.src = '" <> ~p"/images/cover-not-found.png" <> "';"}
                />
                <div class="min-w-0 flex-1">
                  <p class="truncate text-xs text-zinc-500 dark:text-zinc-400">
                    {item.artists}
                  </p>
                  <p class="truncate text-sm font-medium text-zinc-700 dark:text-zinc-300">
                    {item.title}
                  </p>
                  <div class="mt-1 flex items-center gap-2">
                    <form phx-change="change_format" phx-target={@myself}>
                      <input type="hidden" name="cart_item_id" value={item.cart_item_id} />
                      <select
                        name="format"
                        aria-label={gettext("Format")}
                        class="rounded-md border border-zinc-300 dark:border-zinc-700 bg-white dark:bg-zinc-950 text-xs px-1.5 py-0.5"
                      >
                        <option
                          :for={format <- Records.Record.formats()}
                          value={format}
                          selected={format == item.format}
                        >
                          {format_label(format)}
                        </option>
                      </select>
                    </form>
                    <button
                      type="button"
                      phx-click="remove_from_cart"
                      phx-value-cart_item_id={item.cart_item_id}
                      phx-target={@myself}
                      class="text-xs text-zinc-500 hover:text-red-600 dark:hover:text-red-400"
                    >
                      {gettext("Remove")}
                    </button>
                  </div>
                </div>
              </li>
            </ul>

            <div
              :if={@cart != []}
              class="border-t border-zinc-200 dark:border-zinc-800 px-4 py-3"
            >
              <.button
                variant="solid"
                phx-click="import_cart"
                phx-target={@myself}
                disabled={@importing?}
                class="w-full"
              >
                <.icon
                  :if={@importing?}
                  name="hero-arrow-path"
                  class="icon animate-spin"
                  aria-hidden="true"
                  data-slot="icon"
                />
                <.icon
                  :if={not @importing?}
                  name="hero-plus"
                  class="icon"
                  aria-hidden="true"
                  data-slot="icon"
                />
                {ngettext(
                  "Import %{count} record",
                  "Import %{count} records",
                  length(@cart),
                  count: length(@cart)
                )}
              </.button>
            </div>
          </div>
        </aside>
      </div>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :icon_name, :string, required: true
  attr :release_group, MusicBrainz.ReleaseGroupSearchResult, required: true
  attr :myself, :any, required: true
  attr :in_cart?, :boolean, required: true
  attr :cart_formats, :list, required: true

  defp result(assigns) do
    ~H"""
    <li
      id={@id}
      class="flex justify-between gap-x-6 py-5 md:px-4 hover:bg-zinc-100 dark:hover:bg-zinc-700"
    >
      <div class="flex w-full shrink-0 items-center justify-between">
        <img
          class="mr-4 w-12 md:w-20 flex-none rounded-lg"
          alt={@release_group.title}
          src={ReleaseGroupSearchResult.thumb_url(@release_group)}
          onerror={"this.src = '" <> ~p"/images/cover-not-found.png" <> "';"}
        />
        <div class="min-w-0 flex-auto">
          <h1 class="truncate text-sm/6 text-zinc-700 dark:text-zinc-400">
            {@release_group.artists}
          </h1>
          <h2 class="mt-1 flex truncate text-sm/5 font-semibold text-wrap text-zinc-700 sm:text-base dark:text-zinc-300">
            {@release_group.title}
          </h2>
          <p class="mt-1 text-xs/5 text-zinc-500 dark:text-zinc-400">
            {Records.Record.format_release_date(@release_group.release_date)} · {type_label(
              @release_group.type
            )}
          </p>
        </div>

        <span
          :if={@in_cart?}
          class="mr-2 inline-flex items-center gap-1 rounded-full bg-emerald-100 dark:bg-emerald-500/10 text-emerald-700 dark:text-emerald-300 text-xs font-medium px-2 py-0.5"
        >
          <.icon name="hero-check" class="size-3" aria-hidden="true" data-slot="icon" />
          <span :if={length(@cart_formats) > 1}>{length(@cart_formats)}</span>
          <span class="sr-only sm:not-sr-only">{gettext("In cart")}</span>
        </span>

        <.dropdown id={"actions-#{@release_group.id}"} placement="bottom-end">
          <:toggle>
            <span class="sr-only">{gettext("Choose which format to add")}</span>
            <.icon
              name="hero-plus"
              class="size-5 cursor-pointer text-zinc-500 dark:text-zinc-400"
              aria-hidden="true"
              data-slot="icon"
            />
          </:toggle>
          <.focus_wrap id={"actions-#{@release_group.id}-focus-wrap"}>
            <.dropdown_link
              :for={format <- Records.Record.formats()}
              id={"actions-#{@release_group.id}-#{format}-add"}
              phx-click={
                JS.push("add_to_cart",
                  value: %{id: @release_group.id, format: format},
                  target: @myself
                )
              }
            >
              {format_label(format)}
            </.dropdown_link>
          </.focus_wrap>
        </.dropdown>
      </div>
    </li>
    """
  end

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:release_groups, [])
     |> assign(:release_groups_count, 0)
     |> assign(:release_groups_total_count, 0)
     |> assign(:loaded_all_results?, false)
     |> assign(:error_message, nil)
     |> assign(:cart, [])
     |> assign(:cart_pairs, MapSet.new())
     |> assign(:cart_expanded?, true)
     |> assign(:importing?, false)}
  end

  @impl true
  def update(assigns, socket) do
    mb_query = assigns.initial_query || ""

    socket =
      if mb_query == "" do
        socket
      else
        case MusicBrainz.search_release_group(mb_query, limit: @batch_size, offset: 0) do
          {:ok, result} ->
            socket
            |> assign(:error_message, nil)
            |> assign(:release_groups_count, Enum.count(result.release_groups))
            |> assign(:release_groups_total_count, result.total_count)
            |> assign(:release_groups, result.release_groups)

          {:error, _reason} ->
            assign(
              socket,
              :error_message,
              gettext("Could not search MusicBrainz. Please try again.")
            )
        end
      end

    {:ok,
     assign(socket,
       offset: 0,
       icon_name: assigns.icon_name,
       purchased_at_fn: assigns.purchased_at_fn,
       form: to_form(%{"mb_query" => mb_query})
     )}
  end

  @impl true
  def handle_event("search", %{"mb_query" => ""}, socket) do
    {:noreply,
     socket
     |> assign(:offset, 0)
     |> assign(:release_groups_count, 0)
     |> assign(:release_groups_total_count, 0)
     |> assign(:release_groups, [])
     |> assign(:form, to_form(%{"mb_query" => ""}))}
  end

  def handle_event("search", %{"mb_query" => mb_query}, socket) do
    case MusicBrainz.search_release_group(mb_query, limit: @batch_size, offset: 0) do
      {:ok, result} ->
        {:noreply,
         socket
         |> assign(:error_message, nil)
         |> assign(:offset, 0)
         |> assign(:release_groups_count, length(result.release_groups))
         |> assign(:release_groups_total_count, result.total_count)
         |> assign(:release_groups, result.release_groups)
         |> assign(:form, to_form(%{"mb_query" => mb_query}))}

      {:error, _reason} ->
        {:noreply,
         socket
         |> assign(:error_message, gettext("Could not search MusicBrainz. Please try again."))
         |> assign(:offset, 0)
         |> assign(:release_groups_count, 0)
         |> assign(:release_groups_total_count, 0)
         |> assign(:release_groups, [])
         |> assign(:form, to_form(%{"mb_query" => mb_query}))}
    end
  end

  def handle_event("load-more", _params, socket) do
    %{"mb_query" => mb_query} = socket.assigns.form.params
    offset = socket.assigns.offset + @batch_size

    case MusicBrainz.search_release_group(mb_query, limit: @batch_size, offset: offset) do
      {:ok, result} ->
        {:noreply,
         socket
         |> assign(:offset, offset)
         |> assign(:loaded_all_results?, length(result.release_groups) < @batch_size)
         |> assign(:release_groups_count, offset + length(result.release_groups))
         |> assign(:release_groups_total_count, result.total_count)
         |> assign(
           :release_groups,
           socket.assigns.release_groups ++ result.release_groups
         )}

      {:error, _reason} ->
        {:noreply, socket}
    end
  end

  def handle_event("add_to_cart", %{"id" => rg_id, "format" => format_str}, socket) do
    with release_group when not is_nil(release_group) <-
           Enum.find(socket.assigns.release_groups, &(&1.id == rg_id)),
         {:ok, format} <- parse_format(format_str) do
      {:noreply, add_to_cart(socket, release_group, format)}
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_event("remove_from_cart", %{"cart_item_id" => id}, socket) do
    case cast_id(id) do
      {:ok, id} -> {:noreply, remove_cart_item(socket, id)}
      :error -> {:noreply, socket}
    end
  end

  def handle_event("change_format", %{"cart_item_id" => id, "format" => format_str}, socket) do
    with {:ok, id} <- cast_id(id),
         {:ok, format} <- parse_format(format_str) do
      {:noreply, change_cart_format(socket, id, format)}
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_event("clear_cart", _params, socket) do
    {:noreply,
     socket
     |> assign(:cart, [])
     |> assign(:cart_pairs, MapSet.new())}
  end

  def handle_event("toggle_cart", _params, socket) do
    {:noreply, assign(socket, :cart_expanded?, not socket.assigns.cart_expanded?)}
  end

  def handle_event("import_cart", _params, socket) do
    case socket.assigns.cart do
      [] ->
        {:noreply, socket}

      [single] ->
        purchased_at = socket.assigns.purchased_at_fn.()

        {:noreply,
         socket
         |> assign(:importing?, true)
         |> start_async(:import_cart, fn ->
           Records.import_from_musicbrainz_release_group(single.release_group_id,
             format: single.format,
             purchased_at: purchased_at
           )
         end)}

      items ->
        purchased_at = socket.assigns.purchased_at_fn.()
        purchased_at_iso = purchased_at && DateTime.to_iso8601(purchased_at)

        changesets =
          Enum.map(items, fn item ->
            ImportFromMusicbrainzReleaseGroup.new(%{
              "release_group_id" => item.release_group_id,
              "format" => Atom.to_string(item.format),
              "purchased_at" => purchased_at_iso
            })
          end)

        jobs = Oban.insert_all(changesets)

        if length(jobs) == length(changesets) do
          notify_parent({:imported_async, length(items)})
        else
          Logger.error(
            "Cart import job enqueue failed: only #{length(jobs)}/#{length(changesets)} jobs inserted"
          )

          put_toast!(:error, gettext("Error queuing records for import"))
        end

        {:noreply, socket}
    end
  end

  @impl true
  # If the user closes the modal mid-import, this callback lands on a detached
  # component and is silently dropped by Phoenix — no user-visible bug.
  def handle_async(:import_cart, {:ok, {:ok, record}}, socket) do
    notify_parent({:imported_single, record})
    {:noreply, assign(socket, :importing?, false)}
  end

  def handle_async(:import_cart, {:ok, {:error, reason}}, socket) do
    put_toast!(
      :error,
      gettext("Error importing record") <> ": " <> ErrorMessages.friendly_message(reason)
    )

    {:noreply, assign(socket, :importing?, false)}
  end

  def handle_async(:import_cart, {:exit, reason}, socket) do
    Logger.warning("Cart import crashed: #{inspect(reason)}")
    put_toast!(:error, gettext("Error importing record"))
    {:noreply, assign(socket, :importing?, false)}
  end

  defp add_to_cart(socket, %ReleaseGroupSearchResult{} = release_group, format) do
    pair = {release_group.id, format}

    if MapSet.member?(socket.assigns.cart_pairs, pair) do
      socket
    else
      item = %{
        cart_item_id: System.unique_integer([:positive]),
        release_group_id: release_group.id,
        title: release_group.title,
        artists: release_group.artists,
        release_date: release_group.release_date,
        thumb_url: ReleaseGroupSearchResult.thumb_url(release_group),
        format: format
      }

      socket
      |> assign(:cart, [item | socket.assigns.cart])
      |> assign(:cart_pairs, MapSet.put(socket.assigns.cart_pairs, pair))
    end
  end

  defp remove_cart_item(socket, id) do
    {removed, kept} = Enum.split_with(socket.assigns.cart, &(&1.cart_item_id == id))

    pairs =
      Enum.reduce(removed, socket.assigns.cart_pairs, fn item, acc ->
        MapSet.delete(acc, {item.release_group_id, item.format})
      end)

    socket
    |> assign(:cart, kept)
    |> assign(:cart_pairs, pairs)
  end

  defp change_cart_format(socket, id, new_format) do
    case Enum.find(socket.assigns.cart, &(&1.cart_item_id == id)) do
      nil ->
        socket

      %{format: ^new_format} ->
        socket

      item ->
        new_pair = {item.release_group_id, new_format}

        if MapSet.member?(socket.assigns.cart_pairs, new_pair) do
          socket
        else
          updated = %{item | format: new_format}

          cart =
            Enum.map(socket.assigns.cart, fn
              ^item -> updated
              other -> other
            end)

          pairs =
            socket.assigns.cart_pairs
            |> MapSet.delete({item.release_group_id, item.format})
            |> MapSet.put(new_pair)

          socket
          |> assign(:cart, cart)
          |> assign(:cart_pairs, pairs)
        end
    end
  end

  defp parse_format(nil), do: {:ok, @default_format}

  defp parse_format(format_str) when is_binary(format_str) do
    formats = Records.Record.formats()

    case Enum.find(formats, fn f -> Atom.to_string(f) == format_str end) do
      nil -> :error
      format -> {:ok, format}
    end
  end

  defp parse_format(format) when is_atom(format) do
    if format in Records.Record.formats(), do: {:ok, format}, else: :error
  end

  defp cast_id(id) when is_integer(id), do: {:ok, id}

  defp cast_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {int, ""} -> {:ok, int}
      _ -> :error
    end
  end

  defp in_cart?(cart_pairs, rg_id) do
    Enum.any?(cart_pairs, fn {id, _format} -> id == rg_id end)
  end

  defp cart_formats(cart, rg_id) do
    cart
    |> Enum.filter(&(&1.release_group_id == rg_id))
    |> Enum.map(& &1.format)
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
