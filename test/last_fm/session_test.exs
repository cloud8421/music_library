defmodule LastFm.SessionTest do
  use ExUnit.Case, async: true

  alias LastFm.Session

  doctest LastFm.Session

  @xml """
  <?xml version="1.0" encoding="UTF-8"?>
  <lfm status="ok">
    <session>
      <name>cloud8421</name>
      <key>super-secret</key>
      <subscriber>1</subscriber>
    </session>
  </lfm>
  """

  test "parse/1" do
    assert %Session{
             name: "cloud8421",
             key: "super-secret",
             pro: true
           } == Session.parse(@xml)
  end
end
