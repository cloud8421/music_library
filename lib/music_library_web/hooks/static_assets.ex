defmodule MusicLibraryWeb.Hooks.StaticAssets do
  use MusicLibraryWeb, :live_component

  def on_mount(:default, _params, _session, socket) do
    {:cont, assign(socket, :static_changed, static_changed?(socket))}
  end
end
