defmodule MusicLibrary.Assets.TransformTest do
  use ExUnit.Case, async: true

  doctest MusicLibrary.Assets.Transform

  alias MusicLibrary.Assets.Transform

  defp make_payload(params) do
    params |> JSON.encode!() |> Base.url_encode64(padding: false)
  end

  describe "decode/1 width validation" do
    test "rejects string width" do
      payload = make_payload(%{hash: "abc", width: "300"})
      assert {:error, :invalid_payload} = Transform.decode(payload)
    end

    test "rejects negative width" do
      payload = make_payload(%{hash: "abc", width: -1})
      assert {:error, :invalid_payload} = Transform.decode(payload)
    end

    test "rejects zero width" do
      payload = make_payload(%{hash: "abc", width: 0})
      assert {:error, :invalid_payload} = Transform.decode(payload)
    end

    test "rejects float width" do
      payload = make_payload(%{hash: "abc", width: 300.5})
      assert {:error, :invalid_payload} = Transform.decode(payload)
    end

    test "rejects very large width" do
      payload = make_payload(%{hash: "abc", width: 99_999})
      assert {:error, :invalid_payload} = Transform.decode(payload)
    end

    test "accepts nil width" do
      payload = make_payload(%{hash: "abc", width: nil})
      assert {:ok, %Transform{hash: "abc", width: nil}} = Transform.decode(payload)
    end

    test "accepts max allowed width 2048" do
      payload = make_payload(%{hash: "abc", width: 2048})
      assert {:ok, %Transform{hash: "abc", width: 2048}} = Transform.decode(payload)
    end

    test "accepts width 1" do
      payload = make_payload(%{hash: "abc", width: 1})
      assert {:ok, %Transform{hash: "abc", width: 1}} = Transform.decode(payload)
    end
  end
end
