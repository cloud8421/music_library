defmodule MusicLibraryWeb.ArtistController do
  use MusicLibraryWeb, :controller

  alias MusicLibrary.Artists
  alias MusicLibrary.Assets.Transform
  alias MusicLibraryWeb.CoverController

  def image(conn, %{"musicbrainz_id" => artist_id}) do
    case Artists.get_image(artist_id) do
      nil ->
        not_found(conn)

      %{image_data_hash: hash} ->
        payload =
          %Transform{hash: hash}
          |> Transform.encode!()

        CoverController.show(conn, %{"transform_payload" => payload})
    end
  end

  defp not_found(conn) do
    conn
    |> put_status(:not_found)
    |> text("Not found")
  end
end
