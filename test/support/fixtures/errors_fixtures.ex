defmodule MusicLibrary.ErrorsFixtures do
  @moduledoc """
  Fixtures for ErrorTracker error and occurrence data.

  ErrorTracker is disabled in test (`enabled: false` in config), so we cannot use
  `ErrorTracker.report/3` to seed data. Instead, we insert directly via `MusicLibrary.Repo`
  using ErrorTracker's own schemas.
  """

  alias ErrorTracker.{Error, Occurrence, Stacktrace}
  alias MusicLibrary.Repo

  @doc """
  Inserts an error record with the given attributes merged over defaults.
  """
  def error_fixture(attrs \\ []) do
    defaults = %{
      kind: "RuntimeError",
      reason: "Something went wrong",
      source_line: "lib/my_module.ex:42",
      source_function: "MyModule.do_thing/0",
      status: :unresolved,
      fingerprint:
        error_fingerprint(:runtime_error, "lib/my_module.ex:42", "MyModule.do_thing/0"),
      last_occurrence_at: DateTime.utc_now(),
      muted: false
    }

    defaults
    |> Map.merge(Map.new(attrs))
    |> then(&Repo.insert!(struct!(Error, &1)))
  end

  @doc """
  Inserts an occurrence record associated with the given error.
  """
  def occurrence_fixture(error, attrs \\ []) do
    defaults = %{
      reason: error.reason,
      context: %{user_id: 1},
      breadcrumbs: ["step 1"],
      stacktrace: %Stacktrace{
        lines: [
          %Stacktrace.Line{
            application: "music_library",
            module: "MyModule",
            function: "do_thing",
            arity: 0,
            file: "lib/my_module.ex",
            line: 42
          }
        ]
      },
      error_id: error.id
    }

    defaults
    |> Map.merge(Map.new(attrs))
    |> then(&Repo.insert!(struct!(Occurrence, &1)))
  end

  @doc """
  Generates a fingerprint matching ErrorTracker's algorithm: hex(SHA256(joined_params)).
  """
  def error_fingerprint(kind, source_line, source_function) do
    [kind, source_line, source_function]
    |> Enum.join()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16()
  end
end
