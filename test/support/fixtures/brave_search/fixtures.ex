defmodule BraveSearch.Fixtures do
  @moduledoc false

  @fixtures_folder Path.join([File.cwd!(), "test/support/fixtures/brave_search"])

  @external_resource Path.join([@fixtures_folder, "search_images_response.json"])
  @search_images_response Path.join([@fixtures_folder, "search_images_response.json"])
                          |> File.read!()
                          |> JSON.decode!()

  def search_images_response, do: @search_images_response
end
