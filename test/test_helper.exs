Mox.defmock(APIBehaviourMock, for: MusicLibrary.Records.MusicBrainz.APIBehaviour)
Application.put_env(:music_library, :music_brainz, APIBehaviourMock)

ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(MusicLibrary.Repo, :manual)
