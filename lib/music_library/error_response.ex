defmodule MusicLibrary.ErrorResponse do
  @moduledoc """
  Behaviour shared by all per-API `ErrorResponse` modules.

  Each API (MusicBrainz, Discogs, Wikipedia, Brave Search, OpenAI, Last.fm)
  returns a struct implementing this behaviour on HTTP failure, so
  `MusicLibrary.Worker.ErrorHandler.to_oban_result/1` can dispatch uniformly
  to produce the right Oban tuple (`{:snooze, n}` / `{:cancel, reason}`)
  without needing to know which API raised the error.
  """

  @doc """
  Returns `true` if the error is transient and the worker should retry after
  a delay; `false` if the error is permanent and the worker should cancel.
  """
  @callback retryable?(struct()) :: boolean()

  @doc """
  Returns the snooze delay in seconds for retryable errors. Implementations
  may return any positive integer; common defaults are 30–60 s.
  """
  @callback retry_delay_seconds(struct()) :: pos_integer()
end
