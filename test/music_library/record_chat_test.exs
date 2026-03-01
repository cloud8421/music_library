defmodule MusicLibrary.RecordChatTest do
  use ExUnit.Case

  alias MusicLibrary.RecordChat

  test "implements the Chat behaviour" do
    Code.ensure_loaded!(RecordChat)
    assert function_exported?(RecordChat, :stream_response, 3)
  end
end
