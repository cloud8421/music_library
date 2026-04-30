defmodule MusicLibrary.Records.Query do
  @moduledoc """
  Helpers to compose Ecto queries based on record-like schemas.
  """

  alias MusicLibrary.Records.SearchIndex

  @spec essential_fields() :: [atom()]
  def essential_fields do
    SearchIndex.__schema__(:fields)
  end

  @doc """
  Ecto query fragment for alphabetical ordering by artist name and title.

  Used by callers that compose queries (e.g. `Collection`) and by search
  ordering internally via `Records.Search`.
  """
  defmacro order_alphabetically do
    quote do
      fragment(
        "unaccent(artists ->> '$[0].sort_name') COLLATE NOCASE ASC, unaccent(title) COLLATE NOCASE ASC"
      )
    end
  end
end
