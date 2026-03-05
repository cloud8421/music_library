defmodule MusicLibraryWeb.ErrorMessages do
  @moduledoc """
  Maps internal error terms to user-friendly messages.

  Used at call sites that previously showed `inspect(reason)` in toasts or assigns.
  Each call site keeps its own contextual prefix (e.g. "Error refreshing cover")
  and appends `": " <> friendly_message(reason)` for the reason part.
  """

  use Gettext, backend: MusicLibraryWeb.Gettext

  # App error atoms
  def friendly_message(:cover_not_available), do: gettext("cover art is not available")
  def friendly_message(:no_duration), do: gettext("release has no track duration information")
  def friendly_message(:medium_not_found), do: gettext("the specified disc was not found")
  def friendly_message(:no_session_key), do: gettext("Last.fm session key is not configured")

  def friendly_message(:already_collected),
    do: gettext("this record is already in your collection")

  def friendly_message(:not_found), do: gettext("the resource was not found")
  def friendly_message(:no_discogs_data), do: gettext("no Discogs profile available")
  def friendly_message(:image_not_found), do: gettext("no image could be found")
  def friendly_message(:invalid_parameters), do: gettext("invalid parameters were provided")
  def friendly_message(:download_failed), do: gettext("the download failed")

  # Last.fm API error atoms
  def friendly_message(:authentication_failed), do: gettext("Last.fm authentication failed")

  def friendly_message(:invalid_session_key),
    do: gettext("Last.fm session has expired, please reconnect")

  def friendly_message(:invalid_api_key), do: gettext("Last.fm API key is invalid")
  def friendly_message(:suspended_api_key), do: gettext("Last.fm API key has been suspended")

  def friendly_message(:rate_limit_exceeded),
    do: gettext("rate limit exceeded, please try again later")

  def friendly_message(:service_offline),
    do: gettext("service is currently offline, please try again later")

  def friendly_message(:transient_error),
    do: gettext("a temporary error occurred, please try again")

  def friendly_message(:operation_failed), do: gettext("the operation failed, please try again")

  def friendly_message(:invalid_resource),
    do: gettext("the requested resource does not exist")

  # Structured errors
  def friendly_message(%Req.TransportError{reason: :timeout}),
    do: gettext("the request timed out, please try again")

  def friendly_message(%Req.TransportError{reason: :econnrefused}),
    do: gettext("the service is not reachable")

  def friendly_message(%Req.TransportError{reason: :nxdomain}),
    do: gettext("the service could not be found")

  def friendly_message(%Req.TransportError{}),
    do: gettext("a connection error occurred, please try again")

  def friendly_message(%Ecto.Changeset{}), do: gettext("validation failed")

  # Fallback
  def friendly_message(_), do: gettext("something went wrong, please try again")
end
