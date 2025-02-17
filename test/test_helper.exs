Mox.defmock(MusicBrainz.APIMock, for: MusicBrainz.APIBehaviour)

music_brainz_config =
  Application.get_env(:music_library, MusicBrainz)
  |> Keyword.put(:api, MusicBrainz.APIMock)

Application.put_env(:music_library, MusicBrainz, music_brainz_config)

Mox.defmock(LastFm.APIMock, for: LastFm.APIBehaviour)

last_fm_config =
  Application.get_env(:music_library, LastFm)
  |> Keyword.put(:api, LastFm.APIMock)

Application.put_env(:music_library, LastFm, last_fm_config)

ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(MusicLibrary.Repo, :manual)
