defmodule MusicLibrary.RecordsOnThisDayEmail do
  @moduledoc false

  import Swoosh.Email
  require Logger

  alias MusicLibrary.Assets.Transform
  alias MusicLibrary.Collection
  alias MusicLibrary.Records.Record

  def send(date) do
    records = Collection.get_records_on_this_day(date)

    if records == [] do
      {:ok, :no_records}
    else
      conf = config()
      from_email = Keyword.fetch!(conf, :from_email)
      to_email = Keyword.fetch!(conf, :to_email)
      mailer = Keyword.fetch!(conf, :mailer)

      heading = Calendar.strftime(date, "Records on %-d %B")

      email =
        new()
        |> to(to_email)
        |> from({"MusicLibrary", from_email})
        |> subject("[MusicLibrary] #{heading}")
        |> html_body(build_html(records, date, conf))

      case mailer.deliver(email) do
        {:ok, _} ->
          Logger.info("Records on this day email sent (#{length(records)} records)")
          {:ok, :sent}

        {:error, reason} ->
          Logger.error("Failed to send records on this day email: #{inspect(reason)}")
          {:error, reason}
      end
    end
  end

  # -- Private --

  defp build_html(records, date, conf) do
    base_url = Keyword.fetch!(conf, :base_url) |> String.trim_trailing("/")
    api_token = Application.get_env(:music_library, MusicLibraryWeb)[:api_token]
    heading = date |> Calendar.strftime("Records on %-d %B") |> html_escape()

    records_html =
      Enum.map_join(records, "\n", fn record -> record_html(record, date, base_url, api_token) end)

    """
    <div style="max-width: 600px; margin: 0 auto; padding: 20px; font-family: system-ui, -apple-system, sans-serif; background-color: #f4f4f5;">
      <div style="background-color: white; border-radius: 8px; padding: 24px; box-shadow: 0 1px 3px 0 rgb(0 0 0 / 0.1);">
        <h1 style="color: #18181b; font-size: 24px; font-weight: bold; margin: 0 0 24px 0;">
          #{heading}
        </h1>
        #{records_html}
      </div>
    </div>
    """
  end

  defp record_html(record, date, base_url, api_token) do
    years = Record.released_how_long_ago?(record, date)
    cover_url = cover_image_url(record, base_url, api_token)
    record_url = record_detail_url(record, base_url)
    artist_names = record |> Record.artist_names() |> html_escape()
    title = record.title |> html_escape()
    years_label = years_ago_label(years)
    {years_color, years_weight} = anniversary_style(years)
    format = format_label(record.format)
    type = type_label(record.type)

    purchased_label =
      if record.purchased_at do
        " · #{Record.format_as_date(record.purchased_at)}"
      else
        ""
      end

    cover_html =
      if cover_url do
        ~s(<img src="#{html_escape(cover_url)}" width="48" height="48" style="width: 48px; height: 48px; object-fit: cover; border-radius: 4px; display: block;" alt="" />)
      else
        ~s(<div style="width: 48px; height: 48px; background-color: #e4e4e7; border-radius: 4px;"></div>)
      end

    """
    <a href="#{html_escape(record_url)}" style="display: flex; gap: 12px; padding: 8px 0; border-bottom: 1px solid #f4f4f5; align-items: center; text-decoration: none; color: inherit;">
      #{cover_html}
      <div style="min-width: 0; flex: 1;">
        <p style="margin: 0; font-size: 13px; color: #52525b; line-height: 1.4;">#{artist_names}</p>
        <p style="margin: 2px 0 0 0; font-size: 15px; font-weight: 600; color: #18181b; line-height: 1.4;">#{title}</p>
        <p style="margin: 2px 0 0 0; font-size: 12px; color: #71717a; line-height: 1.4;">
          <span style="color: #{years_color}; font-weight: #{years_weight};">#{years_label}</span>
          · #{format} · #{type}#{purchased_label}
        </p>
      </div>
    </a>
    """
  end

  defp record_detail_url(record, base_url) do
    "#{base_url}/collection/#{record.id}"
  end

  defp cover_image_url(%{cover_hash: nil}, _base_url, _api_token), do: nil

  defp cover_image_url(record, base_url, api_token) do
    payload = Transform.new(hash: record.cover_hash, width: 96) |> Transform.encode!()
    "#{base_url}/api/assets/#{payload}?token=#{api_token}"
  end

  defp years_ago_label(nil), do: ""
  defp years_ago_label(0), do: "Today"
  defp years_ago_label(1), do: "1 year ago"
  defp years_ago_label(n), do: "#{n} years ago"

  defp anniversary_style(years) when is_integer(years) and years > 0 and rem(years, 10) == 0,
    do: {"#b45309", "bold"}

  defp anniversary_style(years) when is_integer(years) and years > 0 and rem(years, 5) == 0,
    do: {"#6b7280", "bold"}

  defp anniversary_style(0), do: {"#dc2626", "bold"}
  defp anniversary_style(_), do: {"#71717a", "normal"}

  defp format_label(:cd), do: "CD"
  defp format_label(:backup), do: "Backup"
  defp format_label(:vinyl), do: "Vinyl"
  defp format_label(:blu_ray), do: "Blu-ray"
  defp format_label(:dvd), do: "DVD"
  defp format_label(:multi), do: "Multi"
  defp format_label(:digital_download), do: "Download"
  defp format_label(:vhs), do: "VHS"
  defp format_label(:unknown), do: "Unknown"
  defp format_label(_), do: ""

  defp type_label(:album), do: "Album"
  defp type_label(:ep), do: "EP"
  defp type_label(:live), do: "Live"
  defp type_label(:compilation), do: "Comp"
  defp type_label(:single), do: "Single"
  defp type_label(:other), do: "Other"
  defp type_label(_), do: ""

  defp html_escape(value) do
    value |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()
  end

  defp config do
    Application.get_env(:music_library, __MODULE__, [])
  end
end
