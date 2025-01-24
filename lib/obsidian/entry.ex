defmodule Obsidian.Entry do
  @enforce_keys [:type, :musicbrainz_id, :title, :release, :cover_url, :genres]
  defstruct [:type, :musicbrainz_id, :title, :release, :cover_url, :genres]
end
