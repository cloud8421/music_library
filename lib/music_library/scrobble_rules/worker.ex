defmodule MusicLibrary.ScrobbleRules.Worker do
  @moduledoc """
  Oban worker that periodically applies all enabled scrobble rules.

  This worker runs every 30 minutes and applies all enabled transformation rules
  to the scrobbled_tracks table. It logs the results and handles errors gracefully.
  """

  use Oban.Worker, queue: :heavy_writes, max_attempts: 3

  alias MusicLibrary.ScrobbleRules

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: _}) do
    results = ScrobbleRules.apply_all_rules()
    log_results(results)
  end

  defp log_results(results) do
    {applied, errors} =
      Enum.split_with(results, fn
        {:ok, _} -> true
        {:error, _} -> false
      end)

    total_applied = length(applied)
    total_errors = length(errors)

    total_tracks_updated =
      applied
      |> Enum.map(fn {:ok, {_, _, count}} -> count end)
      |> Enum.sum()

    Logger.info(fn ->
      "Scrobble rules application completed: " <>
        "applied #{total_applied} rules, " <>
        "#{total_errors} errors, " <>
        "#{total_tracks_updated} tracks updated"
    end)

    Enum.each(errors, fn {:error, {type, match_value, reason}} ->
      Logger.error(fn ->
        "failed to apply #{type} rule " <>
          "with match #{match_value} " <>
          "with reason #{inspect(reason)}"
      end)
    end)
  end
end
