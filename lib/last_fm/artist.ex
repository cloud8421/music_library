defmodule LastFm.Artist do
  defstruct [:musicbrainz_id, :name]

  @type t :: %__MODULE__{
          musicbrainz_id: String.t(),
          name: String.t()
        }
end
