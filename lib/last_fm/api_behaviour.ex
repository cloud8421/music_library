defmodule LastFm.APIBehaviour do
  alias LastFm.Track

  @type user :: String.t()
  @type api_key :: String.t()
  @callback get_recent_tracks(user, api_key) :: {:ok, [%Track{}]} | {:error, String.t()}
end
