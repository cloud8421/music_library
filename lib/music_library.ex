defmodule MusicLibrary do
  @moduledoc """
  Music Library is an Elixir/Phoenix application for managing a personal music collection.

  It provides comprehensive functionality for tracking music records, integrating with external
  services, and analyzing listening habits.

  ## Core Contexts

  ### Record and Collection Management
  - `MusicLibrary.Records` - Functions to access and manipulate records irrespectively of collection status
  - `MusicLibrary.Collection` - Functions to access and manipulate records in the collection (purchased records)
  - `MusicLibrary.Wishlist` - Functions to access and manipulate records in the wishlist (unpurchased records)
  - `MusicLibrary.Artists` - Functions to access and manage artist information

  ### Search and Discovery
  - `MusicLibrary.Search` - Universal search functionality across records and artists
  - `MusicLibrary.BarcodeScan` - Barcode scanning for quick record identification and import

  ### External Service Integration
  - `MusicLibrary.ScrobbleActivity` - Last.fm integration for scrobble tracking and statistics
  - `MusicLibrary.ScrobbleRules` - Rules system for normalizing scrobbled track metadata

  ### Content and Metadata Management
  - `MusicLibrary.Colors` - Color extraction from album artwork using fast or slow algorithms
  - `MusicLibrary.OnlineStoreTemplates` - Configurable templates for generating online store URLs
  - `MusicLibrary.Secrets` - Encrypted storage for API keys and sensitive configuration
  """

  def timezone, do: Application.fetch_env!(:music_library, :timezone)
end
