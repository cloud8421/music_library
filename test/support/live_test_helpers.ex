defmodule MusicLibraryWeb.LiveTestHelpers do
  def escape(string) do
    string
    |> Phoenix.HTML.html_escape()
    |> Phoenix.HTML.safe_to_string()
  end
end
