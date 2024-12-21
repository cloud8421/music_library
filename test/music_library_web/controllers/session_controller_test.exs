defmodule MusicLibraryWeb.SessionControllerTest do
  use MusicLibraryWeb.ConnCase

  describe "GET /login" do
    @tag :logged_out
    test "it shows the login form", %{conn: conn} do
      conn = get(conn, "/login")

      response = html_response(conn, 200)
      assert response =~ "Welcome to your Music Library"
      assert response =~ "Password"
      assert response =~ "Login"
    end

    test "it resets the session", %{conn: conn} do
      conn = get(conn, "/login")

      session = get_session(conn)

      refute session["logged_in"]
    end
  end

  describe "POST /sessions/create" do
    @tag :logged_out
    test "it refuses an invalid password", %{conn: conn} do
      conn = post(conn, ~p"/sessions/create", %{"password" => "wrong password"})

      {"location", location} =
        conn.resp_headers
        |> List.keyfind("location", 0)

      session = get_session(conn)

      assert conn.status == 302
      assert location == "/login"
      assert conn.assigns.flash == %{"error" => "Invalid password"}
      refute session["logged_in"]
    end

    test "it accepts a valid password", %{conn: conn} do
      valid_password =
        Application.get_env(:music_library, MusicLibraryWeb)
        |> Keyword.fetch!(:login_password)

      conn = post(conn, ~p"/sessions/create", %{"password" => valid_password})

      session = get_session(conn)

      {"location", location} =
        conn.resp_headers
        |> List.keyfind("location", 0)

      assert conn.status == 302
      assert location == "/"
      assert conn.assigns.flash == %{}
      assert session["logged_in"]
    end
  end
end
