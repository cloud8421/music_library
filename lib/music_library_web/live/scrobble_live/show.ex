defmodule MusicLibraryWeb.ScrobbleLive.Show do
  use MusicLibraryWeb, :live_view

  alias MusicLibrary.ScrobbleActivity

  @impl true
  def mount(%{"release_id" => release_id}, _session, socket) do
    {:ok,
     assign(socket,
       current_section: :scrobble,
       release_id: release_id,
       release: nil,
       loading: true,
       can_scrobble: ScrobbleActivity.can_scrobble?(),
       scrobble_form: %{
         "type" => "finished_at",
         "finished_at_date" => Date.utc_today() |> Date.to_string(),
         "finished_at_time" => Time.utc_now() |> Time.truncate(:second) |> Time.to_string(),
         "started_at_date" => Date.utc_today() |> Date.to_string(),
         "started_at_time" => Time.utc_now() |> Time.truncate(:second) |> Time.to_string()
       },
       page_title: "Scrobble Release"
     )}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :show, _params) do
    send(self(), :fetch_release)
    socket
  end

  @impl true
  def handle_event("update_scrobble_form", %{"scrobble" => scrobble_params}, socket) do
    {:noreply, assign(socket, scrobble_form: scrobble_params)}
  end

  def handle_event("scrobble_release", _params, socket) do
    case perform_scrobble(socket.assigns.release, :all, socket.assigns.scrobble_form) do
      {:ok, _result} ->
        {:noreply,
         socket
         |> put_flash(:info, "Release scrobbled successfully!")
         |> push_navigate(to: ~p"/scrobble")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to scrobble release: #{inspect(reason)}")}
    end
  end

  def handle_event("scrobble_medium", %{"medium_number" => medium_number_str}, socket) do
    {medium_number, ""} = Integer.parse(medium_number_str)

    case perform_scrobble(
           socket.assigns.release,
           {:medium, medium_number},
           socket.assigns.scrobble_form
         ) do
      {:ok, _result} ->
        {:noreply,
         socket
         |> put_flash(:info, "Medium scrobbled successfully!")
         |> push_navigate(to: ~p"/scrobble")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to scrobble medium: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_info(:fetch_release, socket) do
    case MusicBrainz.get_release(socket.assigns.release_id) do
      {:ok, release} ->
        release = MusicBrainz.Release.from_api_response(release)

        {:noreply,
         assign(socket,
           release: release,
           loading: false,
           page_title: "Scrobble: #{release.title}"
         )}

      {:error, _reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to fetch release details")
         |> push_navigate(to: ~p"/scrobble")}
    end
  end

  defp perform_scrobble(release, scope, scrobble_form) do
    datetime_opts = build_datetime_opts(scrobble_form)

    case scope do
      :all ->
        ScrobbleActivity.scrobble_release(release, datetime_opts)

      {:medium, medium_number} ->
        ScrobbleActivity.scrobble_medium(medium_number, release, datetime_opts)
    end
  end

  defp build_datetime_opts(%{
         "type" => "finished_at",
         "finished_at_date" => date,
         "finished_at_time" => time
       }) do
    with {:ok, date} <- Date.from_iso8601(date),
         {:ok, time} <- Time.from_iso8601(time),
         datetime <- DateTime.new!(date, time, "Etc/UTC") do
      [finished_at: datetime]
    else
      _ -> [finished_at: DateTime.utc_now()]
    end
  end

  defp build_datetime_opts(%{
         "type" => "started_at",
         "started_at_date" => date,
         "started_at_time" => time
       }) do
    with {:ok, date} <- Date.from_iso8601(date),
         {:ok, time} <- Time.from_iso8601(time),
         datetime <- DateTime.new!(date, time, "Etc/UTC") do
      [started_at: datetime]
    else
      _ -> [started_at: DateTime.utc_now()]
    end
  end

  defp build_datetime_opts(_), do: [finished_at: DateTime.utc_now()]

  defp format_duration(nil), do: "Unknown"

  defp format_duration(milliseconds) when is_integer(milliseconds) do
    seconds = div(milliseconds, 1000)
    minutes = div(seconds, 60)
    remaining_seconds = rem(seconds, 60)

    "#{minutes}:#{String.pad_leading(Integer.to_string(remaining_seconds), 2, "0")}"
  end
end
