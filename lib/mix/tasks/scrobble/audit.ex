defmodule Mix.Tasks.Scrobble.Audit do
  @shortdoc "Audit scrobbled tracks for data quality issues"
  @moduledoc """
  Audit scrobbled tracks to identify data quality issues such as:
  - Missing or empty MusicBrainz IDs for artists
  - Missing or empty MusicBrainz IDs for albums
  - Tracks that could benefit from scrobble rules

  ## Usage

      # Audit all tracks
      mix scrobble.audit

      # Audit and output detailed report
      mix scrobble.audit --verbose

      # Audit and output as JSON
      mix scrobble.audit --format json

      # Audit only tracks with missing artist IDs
      mix scrobble.audit --type artist

      # Audit only tracks with missing album IDs
      mix scrobble.audit --type album

  ## Output

  The task generates a report showing:
  - Total scrobbled tracks
  - Tracks with missing artist MusicBrainz IDs (grouped by artist name)
  - Tracks with missing album MusicBrainz IDs (grouped by album title + artist)
  - Suggested scrobble rules to fix the issues
  """

  use Mix.Task

  import Ecto.Query

  alias LastFm.Track
  alias MusicLibrary.{Repo, ScrobbleActivity}

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    opts = parse_args(args)
    audit_type = Keyword.get(opts, :type, :all)
    format = Keyword.get(opts, :format, :text)
    verbose = Keyword.get(opts, :verbose, false)

    report = generate_audit_report(audit_type, verbose)

    case format do
      :json -> output_json(report)
      :text -> output_text(report, verbose)
    end
  end

  defp parse_args(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        switches: [type: :string, format: :string, verbose: :boolean],
        aliases: [t: :type, f: :format, v: :verbose]
      )

    opts
  end

  defp generate_audit_report(:all, verbose) do
    %{
      total_tracks: ScrobbleActivity.count_tracks(),
      artist_issues: audit_artist_musicbrainz_ids(verbose),
      album_issues: audit_album_musicbrainz_ids(verbose)
    }
  end

  defp generate_audit_report(:artist, verbose) do
    %{
      total_tracks: ScrobbleActivity.count_tracks(),
      artist_issues: audit_artist_musicbrainz_ids(verbose)
    }
  end

  defp generate_audit_report(:album, verbose) do
    %{
      total_tracks: ScrobbleActivity.count_tracks(),
      album_issues: audit_album_musicbrainz_ids(verbose)
    }
  end

  defp count_total_tracks do
    ScrobbleActivity.count_tracks()
  end

  defp audit_artist_musicbrainz_ids(verbose) do
    results = ScrobbleActivity.get_artists_missing_musicbrainz_id()

    total_tracks_affected =
      Enum.reduce(results, 0, fn %{track_count: count}, acc -> acc + count end)

    report = %{
      total_artists: length(results),
      total_tracks_affected: total_tracks_affected,
      artists:
        Enum.map(results, fn %{artist_name: name, track_count: count} ->
          %{name: name, track_count: count}
        end)
    }

    if verbose do
      Map.put(report, :sample_tracks, get_sample_tracks_by_artist(Enum.take(results, 5)))
    else
      report
    end
  end

  defp audit_album_musicbrainz_ids(verbose) do
    results = ScrobbleActivity.get_albums_missing_musicbrainz_id()

    total_tracks_affected =
      Enum.reduce(results, 0, fn %{track_count: count}, acc -> acc + count end)

    report = %{
      total_albums: length(results),
      total_tracks_affected: total_tracks_affected,
      albums:
        Enum.map(results, fn %{album_title: title, artist_name: artist, track_count: count} ->
          %{title: title, artist: artist, track_count: count}
        end)
    }

    if verbose do
      Map.put(report, :sample_tracks, get_sample_tracks_by_album(Enum.take(results, 5)))
    else
      report
    end
  end

  defp get_sample_tracks_by_artist(artists) do
    Enum.map(artists, fn %{artist_name: artist_name} ->
      query =
        from t in Track,
          where:
            fragment("json_extract(?, '$.name') = ?", t.artist, ^artist_name) and
              (fragment("json_extract(?, '$.musicbrainz_id') IS NULL", t.artist) or
                 fragment("json_extract(?, '$.musicbrainz_id') = ''", t.artist)),
          select: %{
            title: t.title,
            album: fragment("json_extract(?, '$.title')", t.album),
            scrobbled_at: t.scrobbled_at_label
          },
          limit: 3

      %{
        artist: artist_name,
        sample_tracks: Repo.all(query)
      }
    end)
  end

  defp get_sample_tracks_by_album(albums) do
    Enum.map(albums, fn %{album_title: album_title, artist_name: artist_name} ->
      query =
        from t in Track,
          where:
            fragment("json_extract(?, '$.title') = ?", t.album, ^album_title) and
              fragment("json_extract(?, '$.name') = ?", t.artist, ^artist_name) and
              (fragment("json_extract(?, '$.musicbrainz_id') IS NULL", t.album) or
                 fragment("json_extract(?, '$.musicbrainz_id') = ''", t.album)),
          select: %{
            title: t.title,
            scrobbled_at: t.scrobbled_at_label
          },
          limit: 3

      %{
        album: album_title,
        artist: artist_name,
        sample_tracks: Repo.all(query)
      }
    end)
  end

  defp output_json(report) do
    report
    |> Jason.encode!(pretty: true)
    |> Mix.Shell.IO.info()
  end

  defp output_text(report, verbose) do
    Mix.Shell.IO.info("\n=== Scrobbled Tracks Data Quality Audit ===\n")
    Mix.Shell.IO.info("Total scrobbled tracks: #{report.total_tracks}\n")

    if Map.has_key?(report, :artist_issues) do
      output_artist_issues(report.artist_issues, verbose)
    end

    if Map.has_key?(report, :album_issues) do
      output_album_issues(report.album_issues, verbose)
    end

    output_summary(report)
  end

  defp output_artist_issues(artist_issues, verbose) do
    Mix.Shell.IO.info("--- Artists with Missing MusicBrainz IDs ---")
    Mix.Shell.IO.info("Unique artists: #{artist_issues.total_artists}")
    Mix.Shell.IO.info("Affected tracks: #{artist_issues.total_tracks_affected}\n")

    if artist_issues.total_artists > 0 do
      Mix.Shell.IO.info("Top artists by track count:")

      artist_issues.artists
      |> Enum.take(10)
      |> Enum.each(fn %{name: name, track_count: count} ->
        Mix.Shell.IO.info("  • #{name} (#{count} tracks)")
      end)

      Mix.Shell.IO.info("")

      if verbose and Map.has_key?(artist_issues, :sample_tracks) do
        Mix.Shell.IO.info("Sample tracks:")

        Enum.each(artist_issues.sample_tracks, fn %{artist: artist, sample_tracks: tracks} ->
          Mix.Shell.IO.info("\n  Artist: #{artist}")

          Enum.each(tracks, fn track ->
            Mix.Shell.IO.info("    - #{track.title} (from #{track.album})")
          end)
        end)

        Mix.Shell.IO.info("")
      end
    end
  end

  defp output_album_issues(album_issues, verbose) do
    Mix.Shell.IO.info("--- Albums with Missing MusicBrainz IDs ---")
    Mix.Shell.IO.info("Unique albums: #{album_issues.total_albums}")
    Mix.Shell.IO.info("Affected tracks: #{album_issues.total_tracks_affected}\n")

    if album_issues.total_albums > 0 do
      Mix.Shell.IO.info("Top albums by track count:")

      album_issues.albums
      |> Enum.take(10)
      |> Enum.each(fn %{title: title, artist: artist, track_count: count} ->
        Mix.Shell.IO.info("  • #{title} by #{artist} (#{count} tracks)")
      end)

      Mix.Shell.IO.info("")

      if verbose and Map.has_key?(album_issues, :sample_tracks) do
        Mix.Shell.IO.info("Sample tracks:")

        Enum.each(album_issues.sample_tracks, fn %{
                                                   album: album,
                                                   artist: artist,
                                                   sample_tracks: tracks
                                                 } ->
          Mix.Shell.IO.info("\n  Album: #{album} by #{artist}")

          Enum.each(tracks, fn track ->
            Mix.Shell.IO.info("    - #{track.title}")
          end)
        end)

        Mix.Shell.IO.info("")
      end
    end
  end

  defp output_summary(report) do
    total_issues =
      (Map.get(report, :artist_issues, %{}) |> Map.get(:total_tracks_affected, 0)) +
        (Map.get(report, :album_issues, %{}) |> Map.get(:total_tracks_affected, 0))

    Mix.Shell.IO.info("--- Summary ---")
    Mix.Shell.IO.info("Total tracks needing enrichment: #{total_issues}")

    Mix.Shell.IO.info("""

    To fix these issues:
    1. Create scrobble rules for artists with missing MusicBrainz IDs:
       - Navigate to the Scrobble Rules page in the app
       - Add artist rules with the correct MusicBrainz ID

    2. Create scrobble rules for albums with missing MusicBrainz IDs:
       - Add album rules with the correct MusicBrainz ID

    3. Apply the rules to update existing tracks:
       - Use the "Apply Rules" button in the Scrobble Rules page
       - Or run: MusicLibrary.ScrobbleRules.apply_all_rules()
    """)
  end
end
