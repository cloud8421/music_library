defmodule LastFm.Album do
  defstruct [:musicbrainz_id, :title]

  @type t :: %__MODULE__{
          musicbrainz_id: String.t(),
          title: String.t()
        }
end
