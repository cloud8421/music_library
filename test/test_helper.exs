Mox.defmock(MusicBrainz.APIBehaviourMock, for: MusicBrainz.APIBehaviour)
Application.put_env(:music_library, :musicbrainz, MusicBrainz.APIBehaviourMock)

Mox.defmock(LastFm.APIBehaviourMock, for: LastFm.APIBehaviour)
Application.put_env(:music_library, :last_fm, LastFm.APIBehaviourMock)

ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(MusicLibrary.Repo, :manual)
