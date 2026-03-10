defmodule ErrorTracker.ErrorNotifierTest do
  use ExUnit.Case, async: false

  import Swoosh.TestAssertions

  alias ErrorTracker.{Error, ErrorNotifier, Occurrence}

  @config [
    from_email: "test@example.com",
    to_email: "admin@example.com",
    mailer: MusicLibrary.Mailer,
    base_url: "https://example.com"
  ]

  defp occurrence(attrs \\ %{}) do
    struct!(
      %Occurrence{
        error_id: 42,
        reason: "** (RuntimeError) something went wrong",
        context: %{"request.path" => "/test", "live_view.view" => "TestLive"},
        stacktrace: %{
          lines: [
            %{
              module: "MyApp.Controller",
              function: "index/2",
              file: "lib/my_app/controller.ex",
              line: 10
            },
            %{
              module: "Phoenix.Router",
              function: "call/2",
              file: "lib/phoenix/router.ex",
              line: 50
            }
          ]
        }
      },
      attrs
    )
  end

  setup :set_swoosh_global

  setup do
    previous = Application.get_env(:music_library, ErrorNotifier)

    case Process.whereis(ErrorNotifier) do
      nil -> :ok
      pid -> GenServer.stop(pid)
    end

    on_exit(fn ->
      case Process.whereis(ErrorNotifier) do
        nil -> :ok
        pid -> GenServer.stop(pid)
      end

      Application.put_env(:music_library, ErrorNotifier, previous || [])
    end)

    :ok
  end

  describe "init/1" do
    test "returns :ignore when unconfigured" do
      Application.put_env(:music_library, ErrorNotifier, [])
      assert :ignore = ErrorNotifier.init(:unused)
    end
  end

  describe "Email.send/2" do
    test "builds and delivers an email with expected content" do
      Application.put_env(:music_library, ErrorNotifier, @config)

      assert {:ok, :sent} = ErrorNotifier.Email.send(occurrence(), "New Error! (something)")

      assert_email_sent(fn email ->
        assert email.subject =~ "[MusicLibrary] Error:"
        assert email.subject =~ "controller.ex"
        assert [{"", "admin@example.com"}] = email.to
        assert {"MusicLibrary", "test@example.com"} = email.from

        body = email.html_body
        assert body =~ "New Error!"
        assert body =~ "something went wrong"
        assert body =~ "MyApp.Controller.index/2"
        assert body =~ "https://example.com/dev/errors/42"
        assert body =~ "/test"
        assert body =~ "TestLive"
        true
      end)
    end

    test "handles occurrence without stacktrace lines" do
      Application.put_env(:music_library, ErrorNotifier, @config)

      occ = occurrence(%{stacktrace: %{lines: []}})
      assert {:ok, :sent} = ErrorNotifier.Email.send(occ, "Error")

      assert_email_sent(fn email ->
        assert email.subject =~ "unknown"
        assert not (email.html_body =~ "Stack Trace:")
      end)
    end
  end

  describe "throttling" do
    test "throttles repeated errors within the window" do
      Application.put_env(
        :music_library,
        ErrorNotifier,
        Keyword.put(@config, :throttle_seconds, 60)
      )

      {:ok, pid} = ErrorNotifier.start_link([])

      :telemetry.execute([:error_tracker, :error, :new], %{}, %{
        error: %ErrorTracker.Error{id: 1},
        occurrence: occurrence(%{error_id: 1})
      })

      Process.sleep(50)
      assert_email_sent()

      # Second notification for same error: throttled
      :telemetry.execute([:error_tracker, :occurrence, :new], %{}, %{
        error: %ErrorTracker.Error{id: 1},
        occurrence: occurrence(%{error_id: 1})
      })

      Process.sleep(50)
      refute_email_sent()

      GenServer.stop(pid)
    end
  end

  describe "skipping" do
    test "skips notification when error is muted" do
      Application.put_env(:music_library, ErrorNotifier, @config)
      {:ok, pid} = ErrorNotifier.start_link([])

      :telemetry.execute([:error_tracker, :error, :new], %{}, %{
        error: %Error{id: 1, muted: true},
        occurrence: occurrence(%{error_id: 1})
      })

      refute_email_sent()

      GenServer.stop(pid)
    end
  end

  describe "telemetry integration" do
    test "sends email on :error_tracker :error :new event" do
      Application.put_env(:music_library, ErrorNotifier, @config)

      {:ok, pid} = ErrorNotifier.start_link([])

      :telemetry.execute([:error_tracker, :error, :new], %{}, %{
        error: %Error{id: 99},
        occurrence: occurrence(%{error_id: 99})
      })

      Process.sleep(50)
      assert_email_sent(subject: ~r/MusicLibrary/)

      GenServer.stop(pid)
    end
  end
end
