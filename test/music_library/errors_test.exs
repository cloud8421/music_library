defmodule MusicLibrary.ErrorsTest do
  use MusicLibrary.DataCase

  import MusicLibrary.ErrorsFixtures

  alias MusicLibrary.Errors

  # Helper to create an error with a unique fingerprint derived from a tag.
  # Avoids unique constraint violations when creating multiple errors in a test.
  defp unique_error(tag, attrs) do
    line = "#{tag}_line"
    func = "TestModule.#{tag}/0"

    error_fixture(
      Map.merge(
        %{
          source_line: line,
          source_function: func,
          fingerprint: error_fingerprint(:runtime_error, line, func)
        },
        Map.new(attrs)
      )
    )
  end

  describe "list_errors/1" do
    test "returns all errors by default" do
      e1 = unique_error("a", %{reason: "Error A"})
      e2 = unique_error("b", %{reason: "Error B"})

      result = Errors.list_errors()

      assert result.total == 2
      assert Enum.count_until(result.errors, 3) == 2
      ids = Enum.map(result.errors, & &1.id)
      assert e1.id in ids
      assert e2.id in ids
    end

    test "filters by status" do
      _e1 = unique_error("unres", %{status: :unresolved, reason: "Unresolved error"})
      e2 = unique_error("res", %{status: :resolved, reason: "Resolved error"})

      result = Errors.list_errors(status: :resolved)

      assert result.total == 1
      assert Enum.count_until(result.errors, 2) == 1
      assert hd(result.errors).id == e2.id
      assert hd(result.errors).status == :resolved
    end

    test "filters by muted" do
      _e1 = unique_error("unmuted", %{muted: false, reason: "Not muted"})
      e2 = unique_error("muted", %{muted: true, reason: "Muted error"})

      result = Errors.list_errors(muted: true)

      assert result.total == 1
      assert Enum.count_until(result.errors, 2) == 1
      assert hd(result.errors).id == e2.id
      assert hd(result.errors).muted == true
    end

    test "filters by search substring on reason" do
      _e1 = unique_error("first", %{reason: "First error"})
      e2 = unique_error("second", %{reason: "Second error with specific text"})

      result = Errors.list_errors(search: "specific text")

      assert result.total == 1
      assert Enum.count_until(result.errors, 2) == 1
      assert hd(result.errors).id == e2.id
      assert hd(result.errors).reason == "Second error with specific text"
    end

    test "search escapes LIKE wildcards (% and _) to prevent pattern expansion" do
      e1 = unique_error("pct", %{reason: "Error with 100% match"})
      _e2 = unique_error("pctx", %{reason: "Error with 100x match"})

      # Searching for "100%" should only match the exact text "100%",
      # not treat % as a wildcard that would also match "100x".
      result = Errors.list_errors(search: "100%")

      assert result.total == 1
      assert Enum.count_until(result.errors, 2) == 1
      assert hd(result.errors).id == e1.id
    end

    test "respects limit" do
      _e1 = unique_error("lim_a", %{reason: "A"})
      _e2 = unique_error("lim_b", %{reason: "B"})
      _e3 = unique_error("lim_c", %{reason: "C"})

      result = Errors.list_errors(limit: 2)

      assert result.total == 3
      assert Enum.count_until(result.errors, 3) == 2
    end

    test "respects offset" do
      _e1 = unique_error("off_a", %{reason: "A"})
      _e2 = unique_error("off_b", %{reason: "B"})
      _e3 = unique_error("off_c", %{reason: "C"})

      result = Errors.list_errors(offset: 1, limit: 10)

      assert result.total == 3
      assert Enum.count_until(result.errors, 3) == 2
    end

    test "returns empty list when no errors match filters" do
      _e1 = unique_error("real", %{reason: "Real error"})

      result = Errors.list_errors(search: "NONEXISTENT")

      assert result.total == 0
      assert result.errors == []
    end

    test "returns empty list when database has no errors at all" do
      result = Errors.list_errors()

      assert result.total == 0
      assert result.errors == []
    end
  end

  describe "get_error/1" do
    test "returns error with occurrences, occurrence_count, and first_occurrence_at" do
      error = unique_error("get_ok", %{reason: "Something went wrong"})
      _occ1 = occurrence_fixture(error, %{breadcrumbs: ["first"]})
      _occ2 = occurrence_fixture(error, %{breadcrumbs: ["second"]})

      assert {:ok, result} = Errors.get_error(error.id)

      assert result.id == error.id
      assert result.reason == "Something went wrong"
      assert result.occurrence_count == 2
      refute is_nil(result.first_occurrence_at)
      assert Enum.count_until(result.occurrences, 3) == 2

      # Occurrences sorted desc by inserted_at (most recent first)
      [occ1, occ2] = result.occurrences
      assert occ1.breadcrumbs == ["second"]
      assert occ2.breadcrumbs == ["first"]
    end

    test "returns occurrence_count = 0 and first_occurrence_at = nil for error with no occurrences" do
      error = unique_error("no_occ", %{reason: "No occurrences"})

      assert {:ok, result} = Errors.get_error(error.id)

      assert result.occurrence_count == 0
      assert is_nil(result.first_occurrence_at)
      assert result.occurrences == []
    end

    test "returns {:error, :not_found} for non-existent id" do
      assert Errors.get_error(99_999) == {:error, :not_found}
    end
  end

  describe "mute_error/1, unmute_error/1, resolve_error/1, unresolve_error/1" do
    test "mute_error/1 sets muted to true" do
      error = unique_error("mute", %{muted: false})
      assert {:ok, updated} = Errors.mute_error(error.id)
      assert updated.muted == true
    end

    test "unmute_error/1 sets muted to false" do
      error = unique_error("unmute", %{muted: true})
      assert {:ok, updated} = Errors.unmute_error(error.id)
      assert updated.muted == false
    end

    test "resolve_error/1 sets status to :resolved" do
      error = unique_error("res", %{status: :unresolved})
      assert {:ok, updated} = Errors.resolve_error(error.id)
      assert updated.status == :resolved
    end

    test "unresolve_error/1 sets status to :unresolved" do
      error = unique_error("unres", %{status: :resolved})
      assert {:ok, updated} = Errors.unresolve_error(error.id)
      assert updated.status == :unresolved
    end

    test "returns {:error, :not_found} for non-existent id" do
      assert Errors.mute_error(99_999) == {:error, :not_found}
      assert Errors.unmute_error(99_999) == {:error, :not_found}
      assert Errors.resolve_error(99_999) == {:error, :not_found}
      assert Errors.unresolve_error(99_999) == {:error, :not_found}
    end

    test "mute_error/1 on already-muted error succeeds (idempotent)" do
      error = unique_error("mute_idem", %{muted: true})
      assert {:ok, updated} = Errors.mute_error(error.id)
      assert updated.muted == true
    end

    test "unmute_error/1 on already-unmuted error succeeds (idempotent)" do
      error = unique_error("unmute_idem", %{muted: false})
      assert {:ok, updated} = Errors.unmute_error(error.id)
      assert updated.muted == false
    end

    test "resolve_error/1 on already-resolved error succeeds (idempotent)" do
      error = unique_error("res_idem", %{status: :resolved})
      assert {:ok, updated} = Errors.resolve_error(error.id)
      assert updated.status == :resolved
    end

    test "unresolve_error/1 on already-unresolved error succeeds (idempotent)" do
      error = unique_error("unres_idem", %{status: :unresolved})
      assert {:ok, updated} = Errors.unresolve_error(error.id)
      assert updated.status == :unresolved
    end
  end

  describe "escape_like_wildcards/1" do
    test "escapes % and _ characters" do
      assert Errors.escape_like_wildcards("100%") == "100\\%"
      assert Errors.escape_like_wildcards("a_b") == "a\\_b"
      assert Errors.escape_like_wildcards("50%_off") == "50\\%\\_off"
    end

    test "preserves backslash escaping" do
      assert Errors.escape_like_wildcards("a\\b") == "a\\\\b"
    end

    test "passes through normal text unchanged" do
      assert Errors.escape_like_wildcards("normal text") == "normal text"
    end
  end
end
