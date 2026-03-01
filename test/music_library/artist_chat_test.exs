defmodule MusicLibrary.ArtistChatTest do
  use ExUnit.Case

  alias MusicLibrary.ArtistChat

  test "implements the Chat behaviour" do
    Code.ensure_loaded!(ArtistChat)
    assert function_exported?(ArtistChat, :stream_response, 3)
  end
end
