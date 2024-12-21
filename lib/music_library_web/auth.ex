defmodule MusicLibraryWeb.Auth do
  def correct_login_password?(password) do
    Plug.Crypto.secure_compare(correct_password(), password)
  end

  defp correct_password do
    Application.get_env(:music_library, MusicLibraryWeb)
    |> Keyword.fetch!(:auth_password)
  end
end
