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

  @doc """
  Returns `true` when the error kind should not be tracked.

  ## Examples

      iex> MusicLibrary.ErrorIgnorer.ignore?(
      ...>   %ErrorTracker.Error{kind: "Elixir.Phoenix.Router.NoRouteError"},
      ...>   %{}
      ...> )
      true

      iex> MusicLibrary.ErrorIgnorer.ignore?(
      ...>   %ErrorTracker.Error{kind: "Elixir.RuntimeError"},
      ...>   %{}
      ...> )
      false

      iex> MusicLibrary.ErrorIgnorer.ignore?(
      ...>   %ErrorTracker.Error{kind: "Elixir.Ecto.NoResultsError"},
      ...>   %{}
      ...> )
      false
  """
  @impl true
  def ignore?(%ErrorTracker.Error{kind: kind}, _context) when kind in @ignored_kinds, do: true
  def ignore?(_error, _context), do: false
end
