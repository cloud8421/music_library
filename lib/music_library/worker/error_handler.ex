defmodule MusicLibrary.Worker.ErrorHandler do
  @moduledoc """
  Converts context-layer results into Oban worker return values.

  Workers call external APIs that return `{:error, %ErrorResponse{}}` (per-API
  structs) on HTTP failures. This helper recognises any of the known error
  response structs and translates them into the correct Oban tuple:

    * retryable errors → `{:snooze, seconds}` so the attempt isn't consumed
    * non-retryable errors → `{:cancel, reason}` so Oban stops retrying
    * unknown `{:error, reason}` → passed through for Oban's default backoff

  Workers that have app-layer atom-cancel reasons (e.g. `:no_english_wikipedia`,
  `:cover_not_available`) must match those **before** calling this helper, since
  atoms fall through to the generic `{:error, reason}` branch here.
  """

  @error_structs [
    LastFm.API.ErrorResponse,
    MusicBrainz.API.ErrorResponse,
    Discogs.API.ErrorResponse,
    Wikipedia.API.ErrorResponse,
    BraveSearch.API.ErrorResponse,
    OpenAI.API.ErrorResponse
  ]

  @type oban_result ::
          :ok
          | {:ok, term()}
          | {:error, term()}
          | {:cancel, term()}
          | {:snooze, pos_integer()}

  @spec to_oban_result(term()) :: oban_result()
  def to_oban_result(:ok), do: :ok
  def to_oban_result({:ok, _} = result), do: result

  def to_oban_result({:error, %mod{} = response}) when mod in @error_structs do
    if mod.retryable?(response) do
      {:snooze, mod.retry_delay_seconds(response)}
    else
      {:cancel, response}
    end
  end

  def to_oban_result({:error, reason}), do: {:error, reason}
  def to_oban_result({:cancel, _} = result), do: result
  def to_oban_result({:snooze, _} = result), do: result
end
