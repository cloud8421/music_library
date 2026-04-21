defmodule MusicLibraryWeb.CartComponents do
  @moduledoc """
  Shared cart sidebar used by the record import and barcode scanner flows.

  Renders the right-hand `<aside>` shell: header (title, count, Clear all,
  mobile toggle), collapsible body, empty state, items list, and action row.
  Callers provide the per-item markup and action button via slots; cart state
  (`:cart_expanded?`, item collection) and event handlers stay in the host
  LiveComponent.
  """

  use MusicLibraryWeb, :html

  @doc """
  Renders the cart sidebar.

  The default slot is rendered inside a `<ul>` as `<li>` items when `@count > 0`.

  ## Examples

      <.cart_sidebar
        count={length(@cart)}
        expanded?={@cart_expanded?}
        on_clear="clear_cart"
        on_toggle="toggle_cart"
        target={@myself}
        empty_heading={gettext("Your cart is empty")}
        empty_subtext={gettext("Add records from the search results to get started.")}
      >
        <:empty_icon>
          <.icon name="hero-shopping-bag" class="size-8 text-zinc-400" aria-hidden="true" />
        </:empty_icon>
        <:action>
          <.button phx-click="import_cart" phx-target={@myself}>Import</.button>
        </:action>
        <li :for={item <- @cart} id={"cart-item-" <> item.id}>...</li>
      </.cart_sidebar>
  """
  attr :count, :integer, required: true
  attr :expanded?, :boolean, required: true
  attr :on_clear, :string, required: true
  attr :on_toggle, :string, required: true
  attr :target, :any, required: true
  attr :empty_heading, :string, required: true
  attr :empty_subtext, :string, required: true

  slot :empty_icon, required: true
  slot :action
  slot :inner_block

  def cart_sidebar(assigns) do
    ~H"""
    <aside class={[
      "md:col-span-2",
      "border-t md:border-t-0 md:border-l md:border-zinc-200 md:dark:border-zinc-800",
      "flex flex-col"
    ]}>
      <div class="flex items-center justify-between border-b border-zinc-200 px-4 py-3 dark:border-zinc-800">
        <div class="flex items-center gap-2">
          <p class="text-sm font-semibold text-zinc-700 dark:text-zinc-300">
            {gettext("Cart")}
          </p>
          <span class="text-xs text-zinc-500 dark:text-zinc-400">
            {ngettext("%{count} record", "%{count} records", @count, count: @count)}
          </span>
        </div>
        <div class="flex items-center gap-3">
          <button
            :if={@count > 0}
            type="button"
            phx-click={@on_clear}
            phx-target={@target}
            class="text-xs text-zinc-500 hover:text-zinc-900 dark:hover:text-zinc-100"
          >
            {gettext("Clear all")}
          </button>
          <button
            type="button"
            phx-click={@on_toggle}
            phx-target={@target}
            class="rounded-md p-1 text-zinc-500 hover:bg-zinc-200 md:hidden dark:hover:bg-zinc-800"
            aria-label={gettext("Toggle cart")}
          >
            <.icon
              name={if @expanded?, do: "hero-chevron-down", else: "hero-chevron-up"}
              class="size-4"
              aria-hidden="true"
              data-slot="icon"
            />
          </button>
        </div>
      </div>

      <div class={["md:block!", not @expanded? && "hidden"]}>
        <div
          :if={@count == 0}
          id="cart-empty"
          class="flex flex-col items-center justify-center gap-2 px-6 py-10 text-center"
        >
          {render_slot(@empty_icon)}
          <p class="text-sm text-zinc-500 dark:text-zinc-400">
            {@empty_heading}
          </p>
          <p class="text-xs text-zinc-500 dark:text-zinc-400">
            {@empty_subtext}
          </p>
        </div>

        <ul
          :if={@count > 0}
          id="cart-items"
          class="divide-y divide-zinc-200 overflow-y-auto md:max-h-[calc(100vh-20rem)] dark:divide-zinc-800"
        >
          {render_slot(@inner_block)}
        </ul>

        <div
          :if={@count > 0 and @action != []}
          class="border-t border-zinc-200 px-4 py-3 dark:border-zinc-800"
        >
          {render_slot(@action)}
        </div>
      </div>
    </aside>
    """
  end
end
