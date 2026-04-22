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
  alias Mix.Shell.IO, as: ShellIO
  alias MusicLibrary.{ListeningStats, Maintenance, Repo}

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

    # Validate and convert type option
    type =
      case Keyword.get(opts, :type) do
        nil ->
          :all

        "artist" ->
          :artist

        "album" ->
          :album

        other ->
          Mix.raise("Invalid type: #{other}. Valid types are: artist, album")
      end

    # Validate and convert format option
    format =
      case Keyword.get(opts, :format) do
        nil ->
          :text

        "json" ->
          :json

        "text" ->
          :text

        other ->
          Mix.raise("Invalid format: #{other}. Valid formats are: json, text")
      end

    verbose = Keyword.get(opts, :verbose, false)

    [type: type, format: format, verbose: verbose]
  end

  defp generate_audit_report(:all, verbose) do
    %{
      total_tracks: ListeningStats.scrobble_count(),
      artist_issues: audit_artist_musicbrainz_ids(verbose),
      album_issues: audit_album_musicbrainz_ids(verbose)
    }
  end

  defp generate_audit_report(:artist, verbose) do
    %{
      total_tracks: ListeningStats.scrobble_count(),
      artist_issues: audit_artist_musicbrainz_ids(verbose)
    }
  end

  defp generate_audit_report(:album, verbose) do
    %{
      total_tracks: ListeningStats.scrobble_count(),
      album_issues: audit_album_musicbrainz_ids(verbose)
    }
  end

  defp audit_artist_musicbrainz_ids(verbose) do
    results = Maintenance.get_artists_missing_musicbrainz_id()

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
    results = Maintenance.get_albums_missing_musicbrainz_id()

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
    artist_names = Enum.map(artists, & &1.artist_name)

    query =
      from t in Track,
        where:
          fragment("json_extract(?, '$.name')", t.artist) in ^artist_names and
            (fragment("json_extract(?, '$.musicbrainz_id') IS NULL", t.artist) or
               fragment("json_extract(?, '$.musicbrainz_id') = ''", t.artist)),
        select: %{
          artist_name: fragment("json_extract(?, '$.name')", t.artist),
          title: t.title,
          album: fragment("json_extract(?, '$.title')", t.album),
          scrobbled_at: t.scrobbled_at_label
        }

    tracks_by_artist =
      query
      |> Repo.all()
      |> Enum.group_by(& &1.artist_name, fn track -> Map.delete(track, :artist_name) end)

    Enum.map(artists, fn %{artist_name: artist_name} ->
      %{
        artist: artist_name,
        sample_tracks:
          tracks_by_artist
          |> Map.get(artist_name, [])
          |> Enum.take(3)
      }
    end)
  end

  defp get_sample_tracks_by_album(albums) do
    album_keys =
      Enum.map(albums, fn %{album_title: album_title, artist_name: artist_name} ->
        {album_title, artist_name}
      end)

    case album_keys do
      [] ->
        []

      _ ->
        base_query =
          from t in Track,
            where:
              fragment("json_extract(?, '$.musicbrainz_id') IS NULL", t.album) or
                fragment("json_extract(?, '$.musicbrainz_id') = ''", t.album),
            select: %{
              title: t.title,
              scrobbled_at: t.scrobbled_at_label,
              album_title: fragment("json_extract(?, '$.title')", t.album),
              artist_name: fragment("json_extract(?, '$.name')", t.artist)
            }

        album_match_dynamic =
          Enum.reduce(album_keys, false, fn {album_title, artist_name}, dynamic_acc ->
            pair_dynamic =
              dynamic(
                [t],
                fragment("json_extract(?, '$.title') = ?", t.album, ^album_title) and
                  fragment("json_extract(?, '$.name') = ?", t.artist, ^artist_name)
              )

            dynamic([t], ^dynamic_acc or ^pair_dynamic)
          end)

        query =
          from t in base_query,
            where: ^album_match_dynamic

        tracks = Repo.all(query)

        tracks_by_key =
          Enum.group_by(tracks, fn %{album_title: album_title, artist_name: artist_name} ->
            {album_title, artist_name}
          end)

        Enum.map(albums, fn %{album_title: album_title, artist_name: artist_name} ->
          key = {album_title, artist_name}

          sample_tracks =
            tracks_by_key
            |> Map.get(key, [])
            |> Enum.take(3)
            |> Enum.map(fn %{title: title, scrobbled_at: scrobbled_at} ->
              %{title: title, scrobbled_at: scrobbled_at}
            end)

          %{
            album: album_title,
            artist: artist_name,
            sample_tracks: sample_tracks
          }
        end)
    end
  end

  defp output_json(report) do
    report
    |> Jason.encode!(pretty: true)
    |> ShellIO.info()
  end

  defp output_text(report, verbose) do
    ShellIO.info("\n=== Scrobbled Tracks Data Quality Audit ===\n")
    ShellIO.info("Total scrobbled tracks: #{report.total_tracks}\n")

    if Map.has_key?(report, :artist_issues) do
      output_artist_issues(report.artist_issues, verbose)
    end

    if Map.has_key?(report, :album_issues) do
      output_album_issues(report.album_issues, verbose)
    end

    output_summary(report)
  end

  defp output_artist_issues(artist_issues, verbose) do
    ShellIO.info("--- Artists with Missing MusicBrainz IDs ---")
    ShellIO.info("Unique artists: #{artist_issues.total_artists}")
    ShellIO.info("Affected tracks: #{artist_issues.total_tracks_affected}\n")

    if artist_issues.total_artists > 0 do
      ShellIO.info("Top artists by track count:")

      artist_issues.artists
      |> Enum.take(10)
      |> Enum.each(fn %{name: name, track_count: count} ->
        ShellIO.info("  • #{name} (#{count} tracks)")
      end)

      ShellIO.info("")

      if verbose and Map.has_key?(artist_issues, :sample_tracks) do
        ShellIO.info("Sample tracks:")

        Enum.each(artist_issues.sample_tracks, fn %{artist: artist, sample_tracks: tracks} ->
          ShellIO.info("\n  Artist: #{artist}")

          # credo:disable-for-next-line Credo.Check.Refactor.Nesting
          Enum.each(tracks, fn track ->
            ShellIO.info("    - #{track.title} (from #{track.album})")
          end)
        end)

        ShellIO.info("")
      end
    end
  end

  defp output_album_issues(album_issues, verbose) do
    ShellIO.info("--- Albums with Missing MusicBrainz IDs ---")
    ShellIO.info("Unique albums: #{album_issues.total_albums}")
    ShellIO.info("Affected tracks: #{album_issues.total_tracks_affected}\n")

    if album_issues.total_albums > 0 do
      ShellIO.info("Top albums by track count:")

      album_issues.albums
      |> Enum.take(10)
      |> Enum.each(fn %{title: title, artist: artist, track_count: count} ->
        ShellIO.info("  • #{title} by #{artist} (#{count} tracks)")
      end)

      ShellIO.info("")

      if verbose and Map.has_key?(album_issues, :sample_tracks) do
        ShellIO.info("Sample tracks:")

        Enum.each(album_issues.sample_tracks, fn %{
                                                   album: album,
                                                   artist: artist,
                                                   sample_tracks: tracks
                                                 } ->
          ShellIO.info("\n  Album: #{album} by #{artist}")

          # credo:disable-for-next-line Credo.Check.Refactor.Nesting
          Enum.each(tracks, fn track ->
            ShellIO.info("    - #{track.title}")
          end)
        end)

        ShellIO.info("")
      end
    end
  end

  defp output_summary(report) do
    total_issues =
      (Map.get(report, :artist_issues, %{}) |> Map.get(:total_tracks_affected, 0)) +
        (Map.get(report, :album_issues, %{}) |> Map.get(:total_tracks_affected, 0))

    ShellIO.info("--- Summary ---")
    ShellIO.info("Total tracks needing enrichment: #{total_issues}")

    ShellIO.info("""

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
