defmodule MusicLibrary.OnlineStoreTemplatesTest do
  use MusicLibrary.DataCase

  import MusicLibrary.Fixtures.OnlineStoreTemplates
  import MusicLibrary.Fixtures.Records

  alias MusicLibrary.OnlineStoreTemplates

  describe "list_templates/0 and list_enabled_templates/0" do
    test "lists all templates" do
      t1 = online_store_template(%{name: "Amazon", enabled: true})
      t2 = online_store_template(%{name: "Bandcamp", enabled: false})

      all = OnlineStoreTemplates.list_templates()
      ids = Enum.map(all, & &1.id)
      assert t1.id in ids
      assert t2.id in ids
    end

    test "lists only enabled templates" do
      t1 = online_store_template(%{name: "Amazon", enabled: true})
      t2 = online_store_template(%{name: "Bandcamp", enabled: false})

      enabled = OnlineStoreTemplates.list_enabled_templates()
      ids = Enum.map(enabled, & &1.id)
      assert t1.id in ids
      refute t2.id in ids
    end
  end

  describe "list_templates/1" do
    test "filters by name" do
      online_store_template(%{name: "Amazon UK"})
      online_store_template(%{name: "Bandcamp"})

      results = OnlineStoreTemplates.list_templates(query: "Amazon")
      assert Enum.count_until(results, 2) == 1
      assert hd(results).name == "Amazon UK"
    end

    test "filters by description" do
      online_store_template(%{name: "Store A", description: "vinyl marketplace"})
      online_store_template(%{name: "Store B", description: "digital downloads"})

      results = OnlineStoreTemplates.list_templates(query: "vinyl")
      assert Enum.count_until(results, 2) == 1
      assert hd(results).name == "Store A"
    end

    test "respects offset and limit" do
      for i <- 1..3, do: online_store_template(%{name: "Store #{i}"})

      results = OnlineStoreTemplates.list_templates(limit: 1)
      assert Enum.count_until(results, 2) == 1
    end
  end

  describe "count_templates/1" do
    test "counts all templates" do
      online_store_template(%{name: "Amazon"})
      online_store_template(%{name: "Bandcamp"})

      assert OnlineStoreTemplates.count_templates() == 2
    end

    test "counts filtered templates" do
      online_store_template(%{name: "Amazon UK"})
      online_store_template(%{name: "Bandcamp"})

      assert OnlineStoreTemplates.count_templates(query: "Amazon") == 1
    end
  end

  describe "create_template/1" do
    test "creates with valid attrs" do
      assert {:ok, template} =
               OnlineStoreTemplates.create_template(%{
                 name: "Test Store",
                 url_template: "https://example.com/search?q={artist}"
               })

      assert template.name == "Test Store"
      assert template.enabled == true
    end

    test "returns error with invalid attrs" do
      assert {:error, changeset} = OnlineStoreTemplates.create_template(%{name: nil})
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "returns error with invalid URL template" do
      assert {:error, changeset} =
               OnlineStoreTemplates.create_template(%{
                 name: "Bad",
                 url_template: "not-a-url"
               })

      assert %{url_template: ["must be a valid HTTP or HTTPS URL"]} = errors_on(changeset)
    end
  end

  describe "update_template/2" do
    test "updates with valid attrs" do
      template = online_store_template()

      assert {:ok, updated} =
               OnlineStoreTemplates.update_template(template, %{name: "Updated Name"})

      assert updated.name == "Updated Name"
    end
  end

  describe "delete_template/1" do
    test "deletes the template" do
      template = online_store_template()
      assert {:ok, deleted} = OnlineStoreTemplates.delete_template(template)
      assert_raise Ecto.NoResultsError, fn -> OnlineStoreTemplates.get_template!(deleted.id) end
    end
  end

  describe "generate_url/2" do
    test "generates URL from template and record" do
      template =
        online_store_template(%{
          url_template: "https://example.com/search?q={artist}+{title}+{format}"
        })

      rec = record_with_artist("Pink Floyd", %{title: "The Wall", format: :vinyl})

      url = OnlineStoreTemplates.generate_url(template, rec)

      assert url =~ "Pink+Floyd"
      assert url =~ "The+Wall"
      assert url =~ "vinyl"
      assert String.starts_with?(url, "https://example.com/search?q=")
    end
  end
end
