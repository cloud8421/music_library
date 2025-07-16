defmodule MusicLibraryWeb.Hooks.StaticAssets do
  use MusicLibraryWeb, :live_component

  def on_mount(:default, _params, _session, socket) do
    socket =
      if static_changed?(socket) do
        put_toast(socket, :warning, gettext("The application has been updated, please reload."))
      else
        socket
      end

    {:cont, socket}
  end
end
