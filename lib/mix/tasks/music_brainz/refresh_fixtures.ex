defmodule Mix.Tasks.MusicBrainz.RefreshFixtures do
  use Mix.Task

  @shortdoc "Fetch and recreate test fixtures that depend on network resources."
  @moduledoc """
  Fetch and recreate test fixtures that depend on network resources.
  """

  require Logger

  @fixtures_folder Path.join([File.cwd!(), "test/support/fixtures"])

  @fixture_files %{
    "release_group.json" =>
      "https://musicbrainz.org/ws/2/release-group/20790e26-98e4-3ad3-a67f-b674758b942d?fmt=json&inc=artists+genres+releases+release-group-rels",
    "release.json" =>
      "https://musicbrainz.org/ws/2/release/0e290154-5375-4f4f-a658-4a92bf02faa5?fmt=json&inc=release-groups"
  }

  @impl Mix.Task
  def run(_args) do
    Application.ensure_all_started(:finch)
    Finch.start_link(name: __MODULE__)

    Enum.each(@fixture_files, fn {filename, url} ->
      case get(url) do
        {:ok, body} ->
          File.write!(Path.join(@fixtures_folder, filename), body)

        {:error, msg} ->
          Logger.error(msg)
      end
    end)
  end

  defp get(url) do
    req =
      Finch.build(:get, url, [
        {"User-Agent", "MusicLibrary/0.1.0 ( cloud8421@gmail.com )"}
      ])

    Logger.debug("Fetching data from #{url}")

    case Finch.request(req, __MODULE__) do
      {:ok, response} when response.status == 200 ->
        {:ok, response.body}

      {:ok, response} when response.status in 301..308 ->
        location = :proplists.get_value("location", response.headers)
        Logger.debug("Following redirect to #{location}")
        get(location)

      other ->
        msg = "Failed to fetch data from #{url}, reason: #{inspect(other)}"
        Logger.error(msg)
        {:error, msg}
    end
  end
end
