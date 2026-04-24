defmodule MusicLibrary.HttpError do
  @moduledoc """
  Default HTTP status → error kind mapping shared by per-API `ErrorResponse` modules.

  Each API's `ErrorResponse.from_response/1` uses this as a baseline before applying
  API-specific overrides (e.g. MusicBrainz treats 503 as a rate limit, not a server
  error; OpenAI splits HTTP 429 into `:rate_limit` vs `:auth_error` based on the
  body `code`).

  ## Kinds

    * `:rate_limit`   — back off and retry (transient)
    * `:server_error` — retry with backoff (transient)
    * `:timeout`      — retry with shorter backoff (transient)
    * `:auth_error`   — permanent until credentials change
    * `:not_found`    — permanent
    * `:client_error` — permanent (malformed request)
    * `:unknown`      — unclassified; treated as permanent
  """

  @type kind ::
          :rate_limit
          | :server_error
          | :timeout
          | :auth_error
          | :not_found
          | :client_error
          | :unknown

  @spec default_kind(integer()) :: kind()
  def default_kind(429), do: :rate_limit
  def default_kind(status) when status in 500..599, do: :server_error
  def default_kind(status) when status in [401, 403], do: :auth_error
  def default_kind(404), do: :not_found
  def default_kind(status) when status in 400..499, do: :client_error
  def default_kind(_), do: :unknown
end
