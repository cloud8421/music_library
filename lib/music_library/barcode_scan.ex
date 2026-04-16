defmodule MusicLibrary.BarcodeScan do
  @moduledoc """
  Barcode-to-MusicBrainz lookup workflow.
  """

  alias MusicLibrary.BarcodeScan.Result
  alias MusicLibrary.Records
  alias MusicLibrary.Worker.ImportFromMusicbrainzRelease

  @spec scan(String.t()) :: {:ok, Result.t()} | {:error, term()}
  def scan(number) do
    case MusicBrainz.search_release_by_barcode(number) do
      {:ok, [best_match_release | _other_releases]} ->
        format = MusicBrainz.ReleaseSearchResult.format(best_match_release)

        case Records.get_release_status(best_match_release.id, format) do
          :new ->
            {:ok, Result.new(number, best_match_release)}

          {:wishlisted, record_id} ->
            {:ok, Result.wishlisted(number, record_id, best_match_release)}

          {:collected, record_id} ->
            {:ok, Result.collected(number, record_id, best_match_release)}
        end

      {:ok, []} ->
        {:ok, Result.not_found(number)}

      error ->
        error
    end
  end

  @spec should_import_async?([Result.t()]) :: boolean()
  def should_import_async?(scan_results) do
    Enum.count(scan_results, &(&1.status == :new)) >= 2
  end

  @spec import_results_async([Result.t()], DateTime.t()) ::
          {:ok, sync_errors :: [{String.t(), term()}], async_count :: non_neg_integer()}
  def import_results_async(scan_results, current_time) do
    {new_results, other_results} = Enum.split_with(scan_results, &(&1.status == :new))

    sync_errors = import_results(other_results, current_time)

    Enum.each(new_results, fn scan_result ->
      %{
        "release_id" => scan_result.release.id,
        "format" => MusicBrainz.ReleaseSearchResult.format(scan_result.release),
        "purchased_at" => DateTime.to_iso8601(current_time),
        "selected_release_id" => scan_result.release.id
      }
      |> ImportFromMusicbrainzRelease.new()
      |> Oban.insert!()
    end)

    {:ok, sync_errors, length(new_results)}
  end

  @spec import_results([Result.t()], DateTime.t()) :: [{String.t(), term()}]
  def import_results(scan_results, current_time) do
    Enum.reduce(scan_results, [], fn scan_result, errors ->
      case import_result(scan_result, current_time) do
        {:error, reason} ->
          [{scan_result.number, reason} | errors]

        _ ->
          errors
      end
    end)
  end

  defp import_result(scan_result, current_time) do
    case scan_result.status do
      :new ->
        Records.import_from_musicbrainz_release(scan_result.release.id,
          format: MusicBrainz.ReleaseSearchResult.format(scan_result.release),
          purchased_at: current_time,
          selected_release_id: scan_result.release.id
        )

      :wishlisted ->
        scan_result.record_id
        |> Records.get_record!()
        |> Records.update_record(%{
          "purchased_at" => current_time,
          "selected_release_id" => scan_result.release.id
        })

      :collected ->
        {:error, :already_collected}

      :not_found ->
        {:error, :not_found}
    end
  end
end
