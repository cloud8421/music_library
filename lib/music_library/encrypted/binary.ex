defmodule MusicLibrary.Encrypted.Binary do
  @moduledoc false
  use Cloak.Ecto.Binary, vault: MusicLibrary.Vault
end
