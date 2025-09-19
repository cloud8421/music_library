defmodule MusicLibraryWeb.ArtistComponents do
  use MusicLibraryWeb, :html

  alias MusicLibrary.Assets.Transform

  attr :artist, :map, required: true
  attr :image_hash, :string, required: true
  attr :class, :string, required: false
  attr :width, :integer, default: nil

  def artist_image(assigns) do
    payload =
      Transform.new(hash: assigns.image_hash, width: assigns.width)
      |> Transform.encode!()

    assigns = assign(assigns, :payload, payload)

    ~H"""
    <img
      class={@class}
      src={~p"/assets/#{@payload}"}
      alt={@artist.name}
      onerror={"this.src = '" <> ~p"/images/cover-not-found.png" <> "';"}
    />
    """
  end
end
