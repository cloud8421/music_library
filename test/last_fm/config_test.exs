defmodule LastFm.ConfigTest do
  use ExUnit.Case, async: true

  describe "resolve/1" do
    test "reads data from application configuration" do
      assert %LastFm.Config{
               api: LastFm.APIMock,
               api_key: api_key,
               user: user,
               auto_refresh: false,
               refresh_interval: refresh_interval,
               user_agent: user_agent
             } =
               LastFm.Config.resolve(:music_library)

      assert is_binary(api_key)
      assert is_binary(user)
      assert is_binary(user_agent)
      assert is_integer(refresh_interval)
    end
  end
end
