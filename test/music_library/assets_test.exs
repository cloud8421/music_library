defmodule MusicLibrary.AssetsTest do
  use MusicLibrary.DataCase

  alias MusicLibrary.Assets
  alias MusicLibrary.Fixtures

  describe "store/1" do
    test "stores using the hash as key" do
      params = %{
        content: "some content",
        format: "text/plain",
        properties: %{"language" => "english"}
      }

      assert {:ok, asset} = Assets.store(params)
      assert asset.hash == "290F493C44F5D63D06B374D0A5ABD292FAE38B92CAB2FAE5EFEFE1B0E9347F56"
      assert asset.properties == %{"language" => "english"}
      assert asset.content == "some content"
      assert asset.format == "text/plain"
    end

    test "prevents duplicates returning the same asset" do
      params = %{
        content: "some content",
        format: "text/plain",
        properties: %{"language" => "english"}
      }

      assert {:ok, _} = Assets.store(params)
      assert {:ok, _} = Assets.store(params)

      assert 1 = Repo.aggregate(Assets.Asset, :count, :hash)
    end
  end

  describe "store_image/1" do
    test "computes properties automatically" do
      params = %{
        content: Fixtures.Records.marbles_cover_data(),
        format: "image/jpeg"
      }

      assert {:ok, asset} = Assets.store_image(params)
      assert asset.hash == "599407DDF69907D4A60FE13CCAA824D25CF08DC124FD6AA3E8E7ECD98C885FFE"
      assert asset.properties == %{"width" => 400, "height" => 396}
      assert asset.content == Fixtures.Records.marbles_cover_data()
      assert asset.format == "image/jpeg"
    end
  end
end
