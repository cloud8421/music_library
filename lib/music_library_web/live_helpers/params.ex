defmodule MusicLibraryWeb.LiveHelpers.Params do
  def parse_page(nil), do: 1

  def parse_page(page) when is_binary(page) do
    case Integer.parse(page) do
      {num, ""} when num > 0 -> num
      _ -> 1
    end
  end

  def parse_page(_), do: 1

  def parse_page_size(nil, _allowed, default), do: default

  def parse_page_size(page_size, allowed, default) when is_binary(page_size) do
    case Integer.parse(page_size) do
      {num, ""} when num > 0 ->
        if allowed == nil or num in allowed, do: num, else: default

      _ ->
        default
    end
  end

  def parse_page_size(_, _allowed, default), do: default

  def merge_pagination(params, url_params, total_entries, opts \\ []) do
    allowed = Keyword.get(opts, :allowed_page_sizes)
    default_page_size = params[:page_size] || 20

    page = parse_page(url_params["page"])
    page_size = parse_page_size(url_params["page_size"], allowed, default_page_size)

    params
    |> Map.put(:page, page)
    |> Map.put(:page_size, page_size)
    |> Map.put(:total_entries, total_entries)
  end

  def merge_query(params, query) do
    Map.put(params, :query, query)
  end

  def merge_order(params, order) do
    Map.put(params, :order, order)
  end
end
