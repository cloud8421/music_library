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

  embed_templates "layouts/*"

  @nav_base_classes "inline-flex items-center border-b-2 px-1 pt-1 text-sm font-medium"
  @nav_inactive_classes "border-transparent text-zinc-500 hover:border-red-300 hover:text-zinc-700 dark:text-zinc-300 dark:hover:text-zinc-200 dark:hover:border-red-700"
  @nav_active_classes "border-red-500 text-zinc-900 dark:text-zinc-100"

  def section_link_classes(current_section, section) when current_section == section do
    [@nav_base_classes, @nav_active_classes]
  end

  def section_link_classes(_current_section, _section) do
    [@nav_base_classes, @nav_inactive_classes]
  end

  def nav_link_classes do
    [@nav_base_classes, @nav_inactive_classes]
  end
end
