defmodule MusicLibrary.Chat do
  @callback stream_response(
              messages :: list(map()),
              context :: term(),
              callback :: (String.t() -> any())
            ) :: :ok | {:error, term()}
end
