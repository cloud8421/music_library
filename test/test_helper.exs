Mox.defmock(APIBehaviourMock, for: MusicBrainz.APIBehaviour)
Application.put_env(:music_library, :musicbrainz, APIBehaviourMock)

ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(MusicLibrary.Repo, :manual)
