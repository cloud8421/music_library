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

  alias Phoenix.LiveView.JS
  use Gettext, backend: MusicLibraryWeb.Gettext

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
  Renders flash notices.

  ## Examples

      <.flash kind={:info} flash={@flash} />
      <.flash kind={:info} phx-mounted={show("#flash")}>Welcome Back!</.flash>
  """
  attr :id, :string, doc: "the optional id of flash container"
  attr :flash, :map, default: %{}, doc: "the map of flash messages to display"
  attr :title, :string, default: nil
  attr :kind, :atom, values: [:info, :warning, :error], doc: "used for styling and flash lookup"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"

  slot :inner_block, doc: "the optional inner block that renders the flash message"

  def flash(assigns) do
    assigns = assign_new(assigns, :id, fn -> "flash-#{assigns.kind}" end)

    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
      role="alert"
      class={[
        "fixed top-2 right-2 mr-2 w-80 sm:w-96 z-50 rounded-md shadow-md p-3 ring-1 ring-zinc-400 border-l-2",
        @kind == :info &&
          "border-l-emerald-500 bg-white dark:bg-zinc-700 text-emerald-700 dark:text-emerald-300",
        @kind == :warning &&
          "border-l-yellow-500 bg-white dark:bg-zinc-700 text-yellow-900 dark:text-yellow-300",
        @kind == :error &&
          "border-l-red-500 bg-white dark:bg-zinc-700 text-red-900 dark:text-red-300"
      ]}
      {@rest}
    >
      <p :if={@title} class="flex items-center gap-1.5 text-sm font-semibold leading-6">
        <.icon :if={@kind == :info} name="hero-information-circle-mini" class="h-4 w-4" />
        <.icon :if={@kind == :warning} name="hero-exclamation-circle-mini" class="h-4 w-4" />
        <.icon :if={@kind == :error} name="hero-exclamation-circle-mini" class="h-4 w-4" />
        {@title}
      </p>
      <p class="mt-2 text-sm leading-5 text-zinc-700 dark:text-zinc-300">{msg}</p>
      <button type="button" class="group absolute top-1 right-1 p-2" aria-label={gettext("close")}>
        <.icon
          name="hero-x-mark-solid"
          class="text-zinc-700 dark:text-zinc-100 h-5 w-5 opacity-40 group-hover:opacity-70"
        />
      </button>
    </div>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id}>
      <.flash kind={:info} title={gettext("Success!")} flash={@flash} />
      <.flash kind={:warning} title={gettext("Warning!")} flash={@flash} />
      <.flash kind={:error} title={gettext("Error!")} flash={@flash} />
      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error")}
        phx-connected={hide("#server-error")}
        hidden
      >
        {gettext("Hang in there while we get back on track")}
        <.icon name="hero-arrow-path" class="ml-1 h-3 w-3 animate-spin" />
      </.flash>
    </div>
    """
  end

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
