defmodule MusicLibrary.Favicon do
  def favicon_url(url) do
    uri = URI.parse(url)
    "https://www.google.com/s2/favicons?domain=#{uri.host}&sz=16"
  end
end
