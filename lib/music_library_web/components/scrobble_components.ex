defmodule MusicLibraryWeb.ScrobbleComponents do
  @moduledoc """
  Universal search modal and related components.
  """

  use MusicLibraryWeb, :html

  def refresh_lastfm_feed_button(assigns) do
    ~H"""
    <button
      type="button"
      class="phx-click-loading:animate-spin text-zinc-500 hover:text-zinc-900 dark:text-zinc-400 dark:hover:text-zinc-300"
      phx-click={JS.push("refresh_lastfm_feed")}
    >
      <span class="sr-only">{gettext("Refresh LastFm Feed")}</span>
      <.icon name="hero-arrow-path" class="h-5 w-5" aria-hidden="true" data-slot="icon" />
    </button>
    """
  end
end
