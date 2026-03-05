defmodule MusicLibraryWeb.ErrorMessagesTest do
  use ExUnit.Case, async: true

  alias MusicLibraryWeb.ErrorMessages

  describe "friendly_message/1" do
    test "maps known app error atoms" do
      assert ErrorMessages.friendly_message(:cover_not_available) == "cover art is not available"

      assert ErrorMessages.friendly_message(:no_duration) ==
               "release has no track duration information"

      assert ErrorMessages.friendly_message(:medium_not_found) ==
               "the specified disc was not found"

      assert ErrorMessages.friendly_message(:no_session_key) ==
               "Last.fm session key is not configured"

      assert ErrorMessages.friendly_message(:already_collected) ==
               "this record is already in your collection"

      assert ErrorMessages.friendly_message(:not_found) == "the resource was not found"
      assert ErrorMessages.friendly_message(:no_discogs_data) == "no Discogs profile available"
      assert ErrorMessages.friendly_message(:image_not_found) == "no image could be found"

      assert ErrorMessages.friendly_message(:invalid_parameters) ==
               "invalid parameters were provided"

      assert ErrorMessages.friendly_message(:download_failed) == "the download failed"
    end

    test "maps Last.fm API error atoms" do
      assert ErrorMessages.friendly_message(:authentication_failed) ==
               "Last.fm authentication failed"

      assert ErrorMessages.friendly_message(:invalid_session_key) ==
               "Last.fm session has expired, please reconnect"

      assert ErrorMessages.friendly_message(:invalid_api_key) == "Last.fm API key is invalid"

      assert ErrorMessages.friendly_message(:suspended_api_key) ==
               "Last.fm API key has been suspended"

      assert ErrorMessages.friendly_message(:rate_limit_exceeded) ==
               "rate limit exceeded, please try again later"

      assert ErrorMessages.friendly_message(:service_offline) ==
               "service is currently offline, please try again later"

      assert ErrorMessages.friendly_message(:transient_error) ==
               "a temporary error occurred, please try again"

      assert ErrorMessages.friendly_message(:operation_failed) ==
               "the operation failed, please try again"

      assert ErrorMessages.friendly_message(:invalid_resource) ==
               "the requested resource does not exist"
    end

    test "maps Req.TransportError with common reasons" do
      assert ErrorMessages.friendly_message(%Req.TransportError{reason: :timeout}) ==
               "the request timed out, please try again"

      assert ErrorMessages.friendly_message(%Req.TransportError{reason: :econnrefused}) ==
               "the service is not reachable"

      assert ErrorMessages.friendly_message(%Req.TransportError{reason: :nxdomain}) ==
               "the service could not be found"

      assert ErrorMessages.friendly_message(%Req.TransportError{reason: :closed}) ==
               "a connection error occurred, please try again"
    end

    test "maps Ecto.Changeset" do
      changeset = Ecto.Changeset.change(%MusicLibrary.Records.Record{})
      assert ErrorMessages.friendly_message(changeset) == "validation failed"
    end

    test "returns fallback for unknown terms" do
      assert ErrorMessages.friendly_message(:unknown_error) ==
               "something went wrong, please try again"

      assert ErrorMessages.friendly_message("some string") ==
               "something went wrong, please try again"

      assert ErrorMessages.friendly_message({:complex, :term}) ==
               "something went wrong, please try again"
    end
  end
end
