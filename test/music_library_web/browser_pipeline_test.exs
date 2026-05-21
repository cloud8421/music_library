defmodule MusicLibraryWeb.BrowserPipelineTest do
  use MusicLibraryWeb.ConnCase

  describe "Content-Security-Policy header" do
    @describetag :logged_out

    test "includes project-specific directives on HTML responses", %{conn: conn} do
      conn = get(conn, ~p"/health")

      assert [csp] = get_resp_header(conn, "content-security-policy")

      # Baseline
      assert csp =~ "default-src 'self'"

      # App-specific image origins (cover art, Brave search)
      assert csp =~ "img-src 'self' data: blob:"
      assert csp =~ "https://lastfm.freetls.fastly.net"
      assert csp =~ "https://imgs.search.brave.com"
      assert csp =~ "https://coverartarchive.org"

      # Worker support (barcode-detector WASM)
      assert csp =~ "worker-src 'self' blob:"

      # Connect for CDN (barcode-detector JS)
      assert csp =~ "connect-src 'self' https://fastly.jsdelivr.net"

      # No framing from other origins
      assert csp =~ "frame-ancestors 'self'"

      # Base URI locked to same origin
      assert csp =~ "base-uri 'self'"
    end
  end
end
