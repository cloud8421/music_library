defmodule MusicLibraryWeb.CoreComponents do
  @moduledoc """
  Provides core UI components.

  At first glance, this module may seem daunting, but its goal is to provide
  core building blocks for your application, such as modals, tables, and
  forms. The components consist mostly of markup and are well-documented
  with doc strings and declarative assigns. You may customize and style
  them in any way you want, based on your application growth and needs.

  The default components use Tailwind CSS, a utility-first CSS framework.
  See the [Tailwind CSS documentation](https://tailwindcss.com) to learn
  how to customize them or feel free to swap in another framework altogether.

  Icons are provided by [heroicons](https://heroicons.com). See `icon/1` for usage.
  """
  use Phoenix.Component
  use Gettext, backend: MusicLibraryWeb.Gettext

  alias Phoenix.LiveView.JS

  defdelegate badge(assigns), to: Fluxon.Components.Badge
  defdelegate button(assigns), to: Fluxon.Components.Button
  defdelegate date_time_picker(assigns), to: Fluxon.Components.DatePicker
  defdelegate dropdown(assigns), to: Fluxon.Components.Dropdown
  defdelegate dropdown_button(assigns), to: Fluxon.Components.Dropdown
  defdelegate dropdown_link(assigns), to: Fluxon.Components.Dropdown
  defdelegate dropdown_separator(assigns), to: Fluxon.Components.Dropdown
  defdelegate input(assigns), to: Fluxon.Components.Input
  defdelegate label(assigns), to: Fluxon.Components.Form
  defdelegate loading(assigns), to: Fluxon.Components.Loading
  defdelegate modal(assigns), to: Fluxon.Components.Modal
  defdelegate select(assigns), to: Fluxon.Components.Select
  defdelegate separator(assigns), to: Fluxon.Components.Separator
  defdelegate sheet(assigns), to: Fluxon.Components.Sheet

  @doc """
  Renders a simple form.

  ## Examples

      <.simple_form for={@form} phx-change="validate" phx-submit="save">
        <.input field={@form[:email]} label="Email"/>
        <.input field={@form[:username]} label="Username" />
        <:actions>
          <button>Save</button>
        </:actions>
      </.simple_form>
  """
  attr :for, :any, required: true, doc: "the data structure for the form"
  attr :as, :any, default: nil, doc: "the server side parameter to collect all input under"

  attr :rest, :global,
    include: ~w(autocomplete name rel action enctype method novalidate target multipart),
    doc: "the arbitrary HTML attributes to apply to the form tag"

  slot :inner_block, required: true
  slot :actions, doc: "the slot for form actions, such as a submit button"

  def simple_form(assigns) do
    ~H"""
    <.form :let={f} for={@for} as={@as} {@rest}>
      <div class="mt-10 space-y-8 bg-white dark:bg-zinc-800">
        {render_slot(@inner_block, f)}
        <div :for={action <- @actions} class="mt-2 flex items-center justify-between gap-6">
          {render_slot(action, f)}
        </div>
      </div>
    </.form>
    """
  end

  @doc """
  Renders a [Heroicon](https://heroicons.com).

  Heroicons come in three styles – outline, solid, and mini.
  By default, the outline style is used, but solid and mini may
  be applied by using the `-solid` and `-mini` suffix.

  You can customize the size and colors of the icons by setting
  width, height, and background color classes.

  Icons are extracted from the `deps/heroicons` directory and bundled within
  your compiled app.css by the plugin in your `assets/tailwind.config.js`.

  ## Examples

      <.icon name="hero-x-mark-solid" />
      <.icon name="hero-arrow-path" class="ml-1 w-3 h-3 animate-spin" />
  """
  attr :name, :string, required: true
  attr :class, :string, default: nil
  attr :rest, :global

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} {@rest} />
    """
  end

  attr :title, :string, required: true
  attr :data, :map, required: true

  def json_viewer(assigns) do
    ~H"""
    <details class="mt-4 px-4 text-zinc-700 hover:text-zinc-500 dark:text-zinc-400 dark:hover:text-zinc-300">
      <summary class="text-xs sm:text-sm cursor-pointer">{@title}</summary>
      <pre><code class="text-xs sm:text-sm"><%= Jason.encode!(@data, pretty: true) %></code></pre>
    </details>
    """
  end

  attr :id, :string, required: true
  attr :class, :string, default: nil
  attr :background_container_target, :string, required: true
  slot :links, required: true
  slot :button, required: false

  def actions_menu(assigns) do
    ~H"""
    <div class={["relative flex-none", @class]}>
      <button
        type="button"
        class="text-zinc-500 hover:text-zinc-900 dark:text-zinc-400 dark:hover:text-zinc-300"
        aria-expanded="false"
        aria-haspopup="true"
        phx-click={toggle_actions_menu(@id, @background_container_target)}
      >
        {render_slot(@button) || default_actions_menu_button(%{})}
      </button>
      <.focus_wrap
        id={"actions-#{@id}"}
        class={[
          "hidden pointer-events-auto absolute right-0 z-10 mt-2 w-48 origin-top-right rounded-md bg-white dark:bg-zinc-800 py-2 shadow-lg ring-1 ring-zinc-900/5 focus:outline-hidden"
        ]}
        role="menu"
        aria-orientation="vertical"
        aria-labelledby="options-menu-0-button"
        phx-click-away={close_actions_menu(@id, @background_container_target)}
      >
        {render_slot(@links)}
      </.focus_wrap>
    </div>
    """
  end

  defp default_actions_menu_button(assigns) do
    ~H"""
    <span class="sr-only">{gettext("Open options")}</span>
    <.icon name="hero-ellipsis-vertical" class="-mt-1 h-5 w-5" aria-hidden="true" data-slot="icon" />
    """
  end

  defp toggle_actions_menu(id, background_container_target) do
    JS.toggle(to: "#actions-#{id}")
    |> JS.toggle_class("pointer-events-none", to: background_container_target)
  end

  defp close_actions_menu(id, background_container_target) do
    JS.hide(to: "#actions-#{id}")
    |> JS.remove_class("pointer-events-none", to: background_container_target)
  end

  ## JS Commands

  def show(js \\ %JS{}, selector) do
    JS.show(js,
      to: selector,
      time: 300,
      transition:
        {"transition-all transform ease-out duration-300",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
         "opacity-100 translate-y-0 sm:scale-100"}
    )
  end

  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 200,
      transition:
        {"transition-all transform ease-in duration-200",
         "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
    )
  end
end
