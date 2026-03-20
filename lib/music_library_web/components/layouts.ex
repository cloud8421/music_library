defmodule MusicLibraryWeb.Layouts do
  @moduledoc """
  This module holds different layouts used by your application.

  See the `layouts` directory for all templates available.
  The "root" layout is a skeleton rendered as part of the
  application router. The "app" layout is set as the default
  layout on both `use MusicLibraryWeb, :controller` and
  `use MusicLibraryWeb, :live_view`.
  """
  use MusicLibraryWeb, :html

  import MusicLibraryWeb.UniversalSearchLive.Index, only: [universal_search_trigger: 1]

  embed_templates "layouts/*"

  attr :current_section, :atom, required: true
  attr :section, :atom, required: true
  attr :route, :string, required: true

  slot :inner_block, required: true

  def nav_link(assigns) do
    ~H"""
    <.link
      navigate={@route}
      class={[
        "inline-flex items-center border-b-2 px-1 pt-1 text-sm font-medium",
        @current_section == @section &&
          "border-red-500 text-zinc-900 dark:text-zinc-100",
        @current_section !== @section &&
          "border-transparent text-zinc-500 hover:border-red-300 hover:text-zinc-700 dark:text-zinc-300 dark:hover:border-red-700 dark:hover:text-zinc-200"
      ]}
    >
      {render_slot(@inner_block)}
    </.link>
    """
  end

  attr :current_section, :atom, required: true
  attr :section, :atom, required: true
  attr :route, :string, required: true
  attr :icon, :string, required: true

  slot :inner_block, required: true

  def dropdown_nav(assigns) do
    ~H"""
    <.dropdown_link
      href={@route}
      class={[
        "rounded-none border-l-2",
        if(@current_section == @section,
          do: "border-l-red-500",
          else: "border-l-transparent"
        )
      ]}
    >
      <.icon name={@icon} class="mr-2 size-4" aria-hidden="true" data-slot="icon" />
      {render_slot(@inner_block)}
    </.dropdown_link>
    """
  end

  defp toast_class_fn(assigns) do
    [
      # base classes
      "bg-white group/toast z-100 pointer-events-auto relative w-full items-center justify-between origin-center overflow-hidden rounded-md p-4 shadow-lg border border-l-4 col-start-1 col-end-1 row-start-1 row-end-2",
      # start hidden if javascript is enabled
      "[@media(scripting:enabled)]:opacity-0 [@media(scripting:enabled){[data-phx-main]_&}]:opacity-100",
      # used to hide the disconnected flashes
      if(assigns[:rest][:hidden] == true, do: "hidden", else: "flex"),
      # override styles per severity
      assigns[:kind] == :info &&
        "!text-green-700 !bg-green-100 border-green-200 border-l-green-400",
      assigns[:kind] == :warning &&
        "!text-yellow-700 !bg-yellow-100 border-yellow-200 border-l-yellow-400",
      assigns[:kind] == :error && "!text-red-700 !bg-red-100 border-red-200 border-l-red-400"
    ]
  end
end
