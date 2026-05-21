defmodule LastFm.SessionTest do
  use ExUnit.Case, async: true

  doctest LastFm.Session

  alias LastFm.Session

  describe "parse/1" do
    test "non-subscriber XML" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <lfm status="ok">
        <session>
          <name>freeuser</name>
          <key>free-key-123</key>
          <subscriber>0</subscriber>
        </session>
      </lfm>
      """

      assert Session.parse(xml) == %Session{
               name: "freeuser",
               key: "free-key-123",
               pro: false
             }
    end

    test "missing subscriber node defaults pro to false" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <lfm status="ok">
        <session>
          <name>basicuser</name>
          <key>basic-key-456</key>
        </session>
      </lfm>
      """

      assert Session.parse(xml) == %Session{
               name: "basicuser",
               key: "basic-key-456",
               pro: false
             }
    end

    test "missing name node returns nil name" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <lfm status="ok">
        <session>
          <key>some-key</key>
          <subscriber>1</subscriber>
        </session>
      </lfm>
      """

      assert Session.parse(xml) == %Session{
               name: nil,
               key: "some-key",
               pro: true
             }
    end

    test "missing key node returns nil key" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <lfm status="ok">
        <session>
          <name>mysteryuser</name>
          <subscriber>0</subscriber>
        </session>
      </lfm>
      """

      assert Session.parse(xml) == %Session{
               name: "mysteryuser",
               key: nil,
               pro: false
             }
    end

    test "missing both name and key nodes returns nil values" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <lfm status="ok">
        <session>
          <subscriber>1</subscriber>
        </session>
      </lfm>
      """

      assert Session.parse(xml) == %Session{
               name: nil,
               key: nil,
               pro: true
             }
    end
  end
end
