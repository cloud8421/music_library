defmodule MusicLibraryWeb.MarkdownTest do
  use ExUnit.Case, async: true

  alias MusicLibraryWeb.Markdown

  doctest MusicLibraryWeb.Markdown

  describe "to_html/1" do
    test "strips script tags" do
      result = Markdown.to_html("<script>alert('xss')</script>")

      refute result =~ "<script>"
      refute result =~ "</script>"
    end

    test "strips event handlers from tags" do
      result = Markdown.to_html("<img src=x onerror=alert(1)>")

      refute result =~ "onerror"
      refute result =~ "alert"
    end

    test "preserves normal markdown formatting" do
      result = Markdown.to_html("**bold**")

      assert result =~ "<strong>bold</strong>"
    end

    test "preserves links" do
      result = Markdown.to_html("[link](http://example.com)")

      assert result =~ "<a"
      assert result =~ "http://example.com"
      assert result =~ "link</a>"
    end
  end
end
