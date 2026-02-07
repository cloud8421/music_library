defmodule MusicLibrary.Fixtures.OnlineStoreTemplates do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `MusicLibrary.OnlineStoreTemplates` context.
  """

  alias MusicLibrary.OnlineStoreTemplates

  def online_store_template(attrs \\ %{}) do
    n = System.unique_integer([:positive])

    {:ok, template} =
      attrs
      |> Enum.into(%{
        name: "Store #{n}",
        description: "A test store template",
        url_template: "https://example.com/search?q={artist}+{title}+{format}",
        enabled: true
      })
      |> OnlineStoreTemplates.create_template()

    template
  end
end
