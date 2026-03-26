defmodule MusicLibraryWeb.MarkdownTest do
  use ExUnit.Case, async: true

  alias MusicLibraryWeb.Markdown

  doctest MusicLibraryWeb.Markdown

  describe "streaming" do
    test "new document renders empty string" do
      doc = Markdown.new_streaming_doc()
      assert Markdown.streaming_to_html(doc) == ""
    end

    test "incremental chunks produce valid HTML" do
      doc = Markdown.new_streaming_doc()
      doc = MDEx.Document.put_markdown(doc, "**bold")
      html = Markdown.streaming_to_html(doc)
      assert html =~ "<strong>bold</strong>"

      doc = MDEx.Document.put_markdown(doc, " text**")
      html = Markdown.streaming_to_html(doc)
      assert html =~ "<strong>bold text</strong>"
    end

    test "sanitizes script tags" do
      doc = Markdown.new_streaming_doc()
      doc = MDEx.Document.put_markdown(doc, "<script>alert(1)</script>")
      html = Markdown.streaming_to_html(doc)
      refute html =~ "<script>"
    end
  end

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
