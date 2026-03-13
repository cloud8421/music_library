defmodule MusicLibrary.Chat do
  @moduledoc """
  Behaviour for streaming AI chat with entity-specific context.
  """

  @callback stream_response(
              messages :: list(map()),
              context :: term(),
              callback :: (String.t() -> any())
            ) :: :ok | {:error, term()}
end
