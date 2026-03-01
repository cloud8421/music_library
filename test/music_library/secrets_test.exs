defmodule MusicLibrary.SecretsTest do
  use MusicLibrary.DataCase

  alias MusicLibrary.Secrets

  describe "store/2" do
    test "stores a secret" do
      assert {:ok, secret} = Secrets.store("test_key", "test_value")
      assert secret.name == "test_key"
    end

    test "replaces an existing secret" do
      {:ok, _} = Secrets.store("test_key", "original")
      {:ok, _} = Secrets.store("test_key", "updated")

      secret = Secrets.get!("test_key")
      assert secret.value == "updated"
    end
  end

  describe "get!/1" do
    test "retrieves a stored secret" do
      {:ok, _} = Secrets.store("test_key", "test_value")

      secret = Secrets.get!("test_key")
      assert secret.name == "test_key"
      assert secret.value == "test_value"
    end

    test "raises when secret does not exist" do
      assert_raise Ecto.NoResultsError, fn ->
        Secrets.get!("nonexistent")
      end
    end
  end

  describe "get/1" do
    test "retrieves a stored secret" do
      {:ok, _} = Secrets.store("test_key", "test_value")

      secret = Secrets.get("test_key")
      assert secret.name == "test_key"
      assert secret.value == "test_value"
    end

    test "returns nil when secret does not exist" do
      assert Secrets.get("nonexistent") == nil
    end
  end
end
