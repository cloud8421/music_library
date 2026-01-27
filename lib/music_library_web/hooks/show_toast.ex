defmodule MusicLibraryWeb.Hooks.ShowToast do
  import Phoenix.LiveView
  import LiveToast, only: [put_toast: 3]

  def put_toast!(type, message) do
    send(self(), {:put_toast, type, message})
  end

  def on_mount(_name, _params, _session, socket) do
    {:cont, attach_hook(socket, :put_toast, :handle_info, &maybe_put_toast/2)}
  end

  defp maybe_put_toast({:put_toast, type, message}, socket) do
    {:halt, put_toast(socket, type, message)}
  end

  defp maybe_put_toast(_, socket), do: {:cont, socket}
end
