defmodule MusicLibraryWeb.ConnCase do
  @moduledoc false

  use ExUnit.CaseTemplate

  using do
    quote do
      use MusicLibraryWeb, :verified_routes

      import MusicLibraryWeb.ConnCase
      import MusicLibraryWeb.LiveTestHelpers
      import Phoenix.ConnTest

      import Phoenix.LiveViewTest,
        # The default endpoint for testing
        only: [
          render_async: 1,
          render_change: 1,
          render_click: 3,
          render_hook: 2,
          render_hook: 3,
          element: 2,
          element: 3,
          form: 3
        ]

      import PhoenixTest
      import Plug.Conn

      @endpoint MusicLibraryWeb.Endpoint

      # Import conveniences for testing with connections
    end
  end

  setup tags do
    MusicLibrary.DataCase.setup_sandbox(tags)

    # The majority of functionality assumes a logged in user,
    # so we default to that.
    conn =
      if tags[:logged_out] do
        Phoenix.ConnTest.build_conn()
      else
        Phoenix.ConnTest.build_conn()
        |> Phoenix.ConnTest.init_test_session(%{logged_in: true})
      end

    {:ok, conn: conn}
  end
end
