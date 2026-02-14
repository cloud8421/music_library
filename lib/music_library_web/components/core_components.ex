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

  import Fluxon.Components.Input

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
      <div class="mt-5 space-y-8 bg-white dark:bg-zinc-800">
        {render_slot(@inner_block, f)}
        <div :for={action <- @actions} class="mt-2 flex items-center justify-between gap-6">
          {render_slot(action, f)}
        </div>
      </div>
    </.form>
    """
  end

  attr :query, :string, required: true

  def search_form(assigns) do
    ~H"""
    <form class="w-full sm:w-1/3" for={@query} phx-submit="search" phx-change="search">
      <.input
        type="search"
        size="sm"
        id={:query}
        name={:query}
        value={@query}
        placeholder={gettext("Search")}
        phx-debounce="500"
        autocomplete="off"
      />
    </form>
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
    <details class="mt-4 text-zinc-700 hover:text-zinc-500 dark:text-zinc-400 dark:hover:text-zinc-300">
      <summary class="text-xs sm:text-sm font-medium cursor-pointer">{@title}</summary>
      <pre><code class="text-xs sm:text-sm">{Jason.encode!(@data, pretty: true)}</code></pre>
    </details>
    """
  end

  attr :title, :string, required: true
  attr :data, :string, required: true

  def text_viewer(assigns) do
    ~H"""
    <details class="mt-4 text-zinc-700 hover:text-zinc-500 dark:text-zinc-400 dark:hover:text-zinc-300">
      <summary class="text-xs sm:text-sm font-medium cursor-pointer">{@title}</summary>
      <code class="whitespace-pre-wrap text-xs sm:text-sm">{@data}</code>
    </details>
    """
  end

  attr :id, :string, required: true
  attr :on_close, :any, required: false, default: nil
  attr :open, :boolean, required: false, default: true

  slot :inner_block, required: true

  def structured_modal(assigns) do
    ~H"""
    <Fluxon.Components.Modal.modal
      id={@id}
      class="mx-auto sm:min-w-2xl max-w-sm md:max-w-3xl mt-8"
      placement="top"
      open={@open}
      on_close={@on_close}
    >
      {render_slot(@inner_block)}
    </Fluxon.Components.Modal.modal>
    """
  end

  attr :external_links, :list, default: []

  def external_links(assigns) do
    ~H"""
    <details
      :if={@external_links != []}
      class="mt-4 text-zinc-700 hover:text-zinc-500 dark:text-zinc-400 dark:hover:text-zinc-300"
    >
      <summary class="text-xs sm:text-sm font-medium cursor-pointer">
        {gettext("External Links")}
      </summary>
      <div class="mt-4 space-y-2">
        <Fluxon.Components.Button.button
          :for={external_link <- @external_links}
          href={external_link.url}
          target="_blank"
          rel="noopener noreferrer"
          variant="ghost"
          size="sm"
          class="ml-2 first:ml-0"
        >
          <img
            class="mr-2"
            src={favicon_url(external_link.url)}
            alt={external_link.name}
            loading="lazy"
          />
          <span class="text-sm font-medium text-zinc-900 dark:text-white">
            {external_link.name}
          </span>
        </Fluxon.Components.Button.button>
      </div>
    </details>
    """
  end

  def favicon_url(url) do
    uri = URI.parse(url)
    "https://www.google.com/s2/favicons?domain=#{uri.host}&sz=16"
  end

  attr :target_id, :string, required: true
  attr :label, :string, required: true

  def copy_to_clipboard(assigns) do
    ~H"""
    <button phx-click={
      JS.dispatch("music_library:clipcopy", to: "#" <> @target_id)
      |> JS.transition("animate-shake")
    }>
      <span class="sr-only">{@label}</span>
      <.icon name="hero-clipboard-document" class="-mt-1 h-5 w-5" aria-hidden="true" data-slot="icon" />
    </button>
    """
  end

  attr :label, :string, required: true
  slot :inner_block, required: true

  def dl_row(assigns) do
    ~H"""
    <div class="py-2 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-0">
      <dt class="text-xs md:text-sm font-medium leading-6 text-zinc-900 dark:text-zinc-400">
        {@label}
      </dt>
      <dd class="mt-1 text-xs md:text-sm leading-6 text-zinc-700 dark:text-zinc-300 sm:col-span-2 sm:mt-0">
        {render_slot(@inner_block)}
      </dd>
    </div>
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

  def translate_error({msg, opts}) do
    # When using gettext, we typically pass the strings we want
    # to translate as a static argument:
    #
    #     # Translate the number of files with plural rules
    #     dngettext("errors", "1 file", "%{count} files", count)
    #
    # However the error messages in our forms and APIs are generated
    # dynamically, so we need to translate them by calling Gettext
    # with our gettext backend as first argument. Translations are
    # available in the errors.po file (as we use the "errors" domain).
    if count = opts[:count] do
      Gettext.dngettext(MusicLibraryWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(MusicLibraryWeb.Gettext, "errors", msg, opts)
    end
  end
end
