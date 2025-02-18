defmodule Mix.Tasks.MusicBrainz.RefreshFixtures do
  use Mix.Task

  @shortdoc "Fetch and recreate test fixtures that depend on network resources."
  @moduledoc """
  Fetch and recreate test fixtures that depend on network resources.
  """

  require Logger

  @fixtures_folder Path.join([File.cwd!(), "test/support/fixtures/music_brainz"])

  @fixture_files %{
    "release_group - marillion - marbles.json" =>
      "https://musicbrainz.org/ws/2/release-group/20790e26-98e4-3ad3-a67f-b674758b942d?fmt=json&inc=artists+genres+releases+release-group-rels",
    "release_group - avantasia - the mystery of time.json" =>
      "https://musicbrainz.org/ws/2/release-group/a40fdacb-2f29-4385-8177-e6b72c93a442?fmt=json&inc=artists+genres+releases+release-group-rels",
    "release_group_with_includes - mariusz duda - lockdown trilogy.json" =>
      "https://musicbrainz.org/ws/2/release-group/5db72bc0-6ce3-4beb-bd51-86b58ed8cf71?fmt=json&inc=artists+genres+releases+release-group-rels",
    "release - marillion - marbles.json" =>
      "https://musicbrainz.org/ws/2/release/d3f9b9e2-73f5-4b47-a2a7-2c2199aad608?fmt=json&inc=release-groups",
    "release - avantasia - the mystery of time.json" =>
      "https://musicbrainz.org/ws/2/release/003d1505-b3ac-4acf-bed1-02e2c8134a26?fmt=json&inc=release-groups"
  }

  @impl Mix.Task
  def run(_args) do
    Application.ensure_all_started(:finch)
    Finch.start_link(name: __MODULE__)

    Enum.each(@fixture_files, fn {filename, url} ->
      case get(url) do
        {:ok, body} ->
          # store the fixture pretty printed
          dest = Path.join(@fixtures_folder, filename)
          content = body |> JSON.decode!() |> Jason.encode!(pretty: true)
          File.write!(dest, content)

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
