defmodule MusicLibraryWeb.LiveTestHelpers do
  def escape(string) do
    string
    |> Phoenix.HTML.html_escape()
    |> Phoenix.HTML.safe_to_string()
  end

  def trigger_hook(session, selector, hook, params \\ %{}) do
    session
    |> PhoenixTest.unwrap(fn view ->
      view
      |> Phoenix.LiveViewTest.element(selector)
      |> Phoenix.LiveViewTest.render_hook(hook, params)
    end)
  end
end
