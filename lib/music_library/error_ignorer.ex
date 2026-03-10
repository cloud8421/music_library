defmodule MusicLibrary.ErrorIgnorer do
  @moduledoc """
  Ignores errors that should not be tracked by ErrorTracker.

  Bot scanners and crawlers routinely hit non-existent paths, generating
  NoRouteError exceptions that are not actionable. We ignore them here
  rather than blocking specific paths in the endpoint.
  """
  @behaviour ErrorTracker.Ignorer

  @ignored_kinds [
    to_string(Phoenix.Router.NoRouteError)
  ]

  @impl true
  def ignore?(%ErrorTracker.Error{kind: kind}, _context) when kind in @ignored_kinds, do: true
  def ignore?(_error, _context), do: false
end
