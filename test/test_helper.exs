Mox.defmock(MusicBrainz.APIMock, for: MusicBrainz.APIBehaviour)

music_brainz_config =
  Application.get_env(:music_library, MusicBrainz)
  |> Keyword.put(:api, MusicBrainz.APIMock)

Application.put_env(:music_library, MusicBrainz, music_brainz_config)

ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(MusicLibrary.Repo, :manual)
