defmodule MusicLibrary.Credo.NoLiveComponentPutToastTest do
  use Credo.Test.Case

  alias MusicLibrary.Credo.NoLiveComponentPutToast

  setup_all do
    {:ok, _apps} = Application.ensure_all_started(:credo)
    :ok
  end

  test "reports direct put_toast/3 calls in LiveComponents" do
    """
    defmodule MusicLibraryWeb.Components.BadToast do
      use MusicLibraryWeb, :live_component

      def handle_event("save", _params, socket) do
        {:noreply, put_toast(socket, :info, "Saved")}
      end
    end
    """
    |> to_source_file()
    |> run_check(NoLiveComponentPutToast)
    |> assert_issue(%{
      line_no: 5,
      message: "Use `put_toast!/2` instead of `put_toast/3` in LiveComponents.",
      trigger: "put_toast"
    })
  end

  test "reports piped put_toast/3 calls in LiveComponents" do
    """
    defmodule MusicLibraryWeb.Components.BadToast do
      use MusicLibraryWeb, :live_component

      def handle_event("save", _params, socket) do
        {:noreply,
         socket
         |> assign(:saved?, true)
         |> put_toast(:info, "Saved")}
      end
    end
    """
    |> to_source_file()
    |> run_check(NoLiveComponentPutToast)
    |> assert_issue(%{
      line_no: 8,
      message: "Use `put_toast!/2` instead of `put_toast/3` in LiveComponents.",
      trigger: "put_toast"
    })
  end

  test "allows put_toast!/2 calls in LiveComponents" do
    """
    defmodule MusicLibraryWeb.Components.GoodToast do
      use MusicLibraryWeb, :live_component

      def handle_event("save", _params, socket) do
        put_toast!(:info, "Saved")
        {:noreply, socket}
      end
    end
    """
    |> to_source_file()
    |> run_check(NoLiveComponentPutToast)
    |> refute_issues()
  end

  test "allows put_toast/3 calls outside LiveComponents" do
    """
    defmodule MusicLibraryWeb.CollectionLive.Index do
      use MusicLibraryWeb, :live_view

      def handle_event("save", _params, socket) do
        {:noreply, put_toast(socket, :info, "Saved")}
      end
    end
    """
    |> to_source_file()
    |> run_check(NoLiveComponentPutToast)
    |> refute_issues()
  end
end
