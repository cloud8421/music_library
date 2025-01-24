defmodule LastFm.Album do
  @enforce_keys [:musicbrainz_id, :title]
  defstruct [:musicbrainz_id, :title]

  @type t :: %__MODULE__{
          musicbrainz_id: String.t(),
          title: String.t()
        }
end
