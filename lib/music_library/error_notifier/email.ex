defmodule MusicLibrary.ErrorNotifier.Email do
  @moduledoc false

  import Swoosh.Email
  require Logger

  def send(occurrence, header) do
    conf = config()
    from_email = Keyword.fetch!(conf, :from_email)
    to_email = Keyword.fetch!(conf, :to_email)
    mailer = Keyword.fetch!(conf, :mailer)

    first_line = first_stack_line(occurrence)
    file = if first_line, do: first_line.file, else: "unknown"
    line = if first_line, do: first_line.line, else: "?"
    error_name = String.slice(occurrence.reason, 0, 80)

    email =
      new()
      |> to(to_email)
      |> from({"MusicLibrary", from_email})
      |> subject("[MusicLibrary] Error: #{error_name} - #{file}:#{line}")
      |> html_body(build_html(occurrence, header))

    case mailer.deliver(email) do
      {:ok, _} ->
        Logger.info("Error notification email sent")
        {:ok, :sent}

      {:error, reason} ->
        Logger.error("Failed to send error notification: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # -- Private --

  defp build_html(occurrence, header) do
    first_line = first_stack_line(occurrence)

    location =
      if first_line do
        "#{first_line.module}.#{first_line.function} (#{first_line.file}:#{first_line.line})"
      else
        "Unknown location"
      end

    view = occurrence.context["live_view.view"] || "N/A"
    path = occurrence.context["request.path"] || "N/A"
    error_url = error_url(occurrence.error_id)

    escaped_header = html_escape(header)
    escaped_error_id = html_escape(occurrence.error_id)
    escaped_reason = occurrence.reason |> String.slice(0..199) |> html_escape()
    escaped_location = html_escape(location)
    escaped_view = html_escape(view)
    escaped_path = html_escape(path)
    escaped_url = html_escape(error_url)
    stack_trace_html = format_stack_trace(occurrence)

    """
    <div style="max-width: 600px; margin: 0 auto; padding: 20px; font-family: system-ui, -apple-system, sans-serif;">
      <div style="background-color: white; border-radius: 8px; padding: 24px; box-shadow: 0 1px 3px 0 rgb(0 0 0 / 0.1);">
        <h1 style="color: #dc2626; font-size: 24px; font-weight: bold; margin-bottom: 16px;">
          #{escaped_header}
        </h1>
        <p style="color: #374151; font-size: 16px; line-height: 24px; margin-bottom: 24px;">
          ErrorTracker has detected an error:
        </p>

        <div style="background-color: #f9fafb; border-radius: 6px; padding: 16px; margin-bottom: 24px;">
          <p><strong>Error ID:</strong> #{escaped_error_id}</p>
          <p><strong>Reason:</strong> #{escaped_reason}</p>
          <p><strong>Location:</strong> #{escaped_location}</p>
          #{stack_trace_html}
          <p><strong>View:</strong> #{escaped_view}</p>
          <p><strong>Request Path:</strong> #{escaped_path}</p>
          <p><strong>Time:</strong> #{DateTime.utc_now()}</p>
        </div>

        <p style="margin-bottom: 24px;">
          <a href="#{escaped_url}"
             style="display: inline-block; background-color: #dc2626; color: white; font-weight: 500;
                    padding: 8px 16px; border-radius: 4px; text-decoration: none;">
            View Error Details
          </a>
        </p>
      </div>
    </div>
    """
  end

  defp format_stack_trace(occurrence) do
    case occurrence.stacktrace do
      %{lines: lines} when is_list(lines) and lines != [] ->
        formatted =
          lines
          |> Enum.take(10)
          |> Enum.map_join("\n", fn line ->
            "#{line.module}.#{line.function} (#{line.file}:#{line.line})"
          end)
          |> html_escape()

        """
        <p style="margin: 8px 0 4px 0;"><strong>Stack Trace:</strong></p>
        <pre style="font-family: 'Courier New', monospace; font-size: 12px; margin: 0; white-space: pre-wrap;">#{formatted}</pre>
        """

      _ ->
        ""
    end
  end

  defp error_url(error_id) do
    conf = config()
    base_url = Keyword.get(conf, :base_url, "")
    error_path = Keyword.get(conf, :error_tracker_path, "/dev/errors")

    error_path = error_path |> String.trim_trailing("/")
    base_url = base_url |> String.trim_trailing("/")

    "#{base_url}#{error_path}/#{error_id}"
  end

  defp first_stack_line(occurrence) do
    case occurrence.stacktrace do
      %{lines: [first | _]} -> first
      _ -> nil
    end
  end

  defp html_escape(value) do
    value |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()
  end

  defp config do
    Application.get_env(:music_library, MusicLibrary.ErrorNotifier, [])
  end
end
