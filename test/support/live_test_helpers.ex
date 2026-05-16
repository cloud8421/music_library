defmodule MusicLibraryWeb.LiveTestHelpers do
  @moduledoc """
  Shared helpers for LiveView tests.

  These helpers sit alongside PhoenixTest and Phoenix.LiveViewTest so tests can
  keep PhoenixTest sessions in the pipeline while still reaching for lower-level
  LiveView interactions when PhoenixTest does not cover them directly.
  """

  @doc """
  Escapes text for assertions against rendered HTML.
  """
  def escape(string) do
    LazyHTML.html_escape(string)
  end

  @doc """
  Waits for LiveView async work to finish.

  Accepts either a PhoenixTest session, returning the session for continued
  piping, or a raw LiveView view/element, returning the rendered HTML from
  `Phoenix.LiveViewTest.render_async/2`.
  """
  def render_async(
        session_or_view,
        timeout \\ Application.fetch_env!(:ex_unit, :assert_receive_timeout)
      )

  def render_async(%{view: %Phoenix.LiveViewTest.View{}} = session, timeout) do
    PhoenixTest.unwrap(session, &Phoenix.LiveViewTest.render_async(&1, timeout))
  end

  def render_async(view_or_element, timeout) do
    Phoenix.LiveViewTest.render_async(view_or_element, timeout)
  end

  @doc """
  Dispatches a hook event to an element inside a PhoenixTest session.
  """
  def trigger_hook(session, selector, hook, params \\ %{}) do
    session
    |> PhoenixTest.unwrap(fn view ->
      view
      |> Phoenix.LiveViewTest.element(selector)
      |> Phoenix.LiveViewTest.render_hook(hook, params)
    end)
  end
end
