Mox.defmock(MusicBrainz.APIBehaviourMock, for: MusicBrainz.APIBehaviour)
Application.put_env(:music_library, :musicbrainz, MusicBrainz.APIBehaviourMock)

Mox.defmock(LastFm.APIBehaviourMock, for: LastFm.APIBehaviour)
last_fm_config = Application.get_env(:music_library, LastFm)
new_last_fm_config = Keyword.put(last_fm_config, :api, LastFm.APIBehaviourMock)
Application.put_env(:music_library, LastFm, new_last_fm_config)

ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(MusicLibrary.Repo, :manual)
