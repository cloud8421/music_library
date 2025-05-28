defmodule MusicLibraryWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use MusicLibraryWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      use MusicLibraryWeb, :verified_routes

      import MusicLibraryWeb.ConnCase
      import MusicLibraryWeb.LiveTestHelpers
      import Phoenix.ConnTest

      import Phoenix.LiveViewTest,
        # The default endpoint for testing
        only: [render: 1, render_async: 1, render_hook: 2, render_hook: 3, element: 2, element: 3]

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
