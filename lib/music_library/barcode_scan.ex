defmodule MusicLibrary.BarcodeScan do
  alias MusicLibrary.BarcodeScan.Result
  alias MusicLibrary.Records

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
        record = Records.get_record!(scan_result.record_id)
        Records.update_record(record, %{"purchased_at" => current_time})

      :collected ->
        {:error, :already_collected}

      :not_found ->
        {:error, :not_found}
    end
  end
end
