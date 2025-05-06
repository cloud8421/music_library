defmodule MusicLibrary.Encrypted.Binary do
  use Cloak.Ecto.Binary, vault: MusicLibrary.Vault
end
