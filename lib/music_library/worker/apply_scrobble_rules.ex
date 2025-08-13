defmodule MusicLibrary.Worker.ApplyScrobbleRules do
  @moduledoc """
  Oban worker that periodically applies all enabled scrobble rules.

  This worker runs every 30 minutes and applies all enabled transformation rules
  to the scrobbled_tracks table. It logs the results and handles errors gracefully.
  """

  use Oban.Worker, queue: :heavy_writes, max_attempts: 3

  alias MusicLibrary.ScrobbleRules

  @impl Oban.Worker
  def perform(%Oban.Job{args: _}) do
    ScrobbleRules.apply_all_rules()
    |> ScrobbleRules.log_apply_results()
  end
end
