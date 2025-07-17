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

  alias Phoenix.LiveView.ColocatedHook

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
          "border-transparent text-zinc-500 hover:border-red-300 hover:text-zinc-700 dark:text-zinc-300 dark:hover:text-zinc-200 dark:hover:border-red-700"
      ]}
    >
      {render_slot(@inner_block)}
    </.link>
    """
  end
end
