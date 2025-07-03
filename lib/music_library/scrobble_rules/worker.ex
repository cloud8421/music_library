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
    Logger.info("Starting scrobble rules application")

    case ScrobbleRules.apply_all_rules() do
      {:ok, results} ->
        log_results(results)

      {:error, reason} ->
        Logger.error("Failed to apply scrobble rules: #{inspect(reason)}")
        {:error, reason}
    end
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

    Logger.info("Scrobble rules application completed", %{
      rules_applied: total_applied,
      rules_failed: total_errors,
      tracks_updated: total_tracks_updated
    })

    # Log individual rule results
    Enum.each(applied, fn {:ok, {type, match_value, count}} ->
      Logger.info("Applied #{type} rule", %{
        match_value: match_value,
        tracks_updated: count
      })
    end)

    # Log errors
    Enum.each(errors, fn {:error, {type, match_value, reason}} ->
      Logger.error("Failed to apply #{type} rule", %{
        match_value: match_value,
        error: reason
      })
    end)
  end
end
