defmodule MusicLibrary.AssetsTest do
  use MusicLibrary.DataCase

  alias MusicLibrary.Assets

  describe "store/1" do
    test "stores using the hash as key" do
      params = %{
        content: "some content",
        format: "text/plain",
        properties: %{language: "english"}
      }

      assert {:ok, asset} = Assets.store(params)
      assert asset.hash == "290F493C44F5D63D06B374D0A5ABD292FAE38B92CAB2FAE5EFEFE1B0E9347F56"
      assert asset.properties == %{"language" => "english"}
      assert asset.content == "some content"
      assert asset.format == "text/plain"
    end

    test "prevents duplicates" do
      params = %{
        content: "some content",
        format: "text/plain",
        properties: %{language: "english"}
      }

      assert {:ok, _asset} = Assets.store(params)
      assert {:error, changeset} = Assets.store(params)

      assert [hash: {"has already been taken", _}] = changeset.errors
    end
  end
end
