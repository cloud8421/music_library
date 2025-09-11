defmodule MusicLibraryWeb.Hooks.GetTimezone do
  use MusicLibraryWeb, :live_component

  def on_mount(:default, _params, _session, socket) do
    connect_params = get_connect_params(socket)
    timezone = connect_params["timezone"] || MusicLibrary.default_timezone()

    {:cont, assign(socket, :timezone, timezone)}
  end
end
