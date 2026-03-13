defmodule MusicLibraryWeb.LiveTestHelpers do
  @moduledoc false

  def escape(string) do
    LazyHTML.html_escape(string)
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
