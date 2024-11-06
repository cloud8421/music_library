Mox.defmock(MusicBrainz.APIBehaviourMock, for: MusicBrainz.APIBehaviour)
Application.put_env(:music_library, :musicbrainz, MusicBrainz.APIBehaviourMock)

ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(MusicLibrary.Repo, :manual)
