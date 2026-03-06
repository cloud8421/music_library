defmodule MusicLibraryWeb.LiveHelpers.Params do
  @pagination Application.compile_env!(:music_library, :pagination)

  @spec parse_page(String.t() | nil | term()) :: pos_integer()
  def parse_page(nil), do: 1

  def parse_page(page) when is_binary(page) do
    case Integer.parse(page) do
      {num, ""} when num > 0 -> num
      _ -> 1
    end
  end

  def parse_page(_), do: 1

  @spec parse_page_size(String.t() | nil | term(), [pos_integer()] | nil, pos_integer()) ::
          pos_integer()
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

  @spec merge_pagination(map(), map(), non_neg_integer(), keyword()) :: map()
  def merge_pagination(params, url_params, total_entries, opts \\ []) do
    allowed = Keyword.get(opts, :allowed_page_sizes)
    default_page_size = params[:page_size] || @pagination[:default_page_size]

    page = parse_page(url_params["page"])
    page_size = parse_page_size(url_params["page_size"], allowed, default_page_size)

    params
    |> Map.put(:page, page)
    |> Map.put(:page_size, page_size)
    |> Map.put(:total_entries, total_entries)
  end

  @spec merge_query(map(), String.t() | nil) :: map()
  def merge_query(params, query) do
    Map.put(params, :query, query)
  end

  @spec merge_order(map(), atom()) :: map()
  def merge_order(params, order) do
    Map.put(params, :order, order)
  end

  @spec apply_fallback_index(Phoenix.LiveView.Socket.t(), map(), atom(), function()) ::
          Phoenix.LiveView.Socket.t()
  def apply_fallback_index(socket, params, stream_key, apply_action_fn) do
    if get_in(socket.assigns, [:streams, stream_key]) == nil do
      apply_action_fn.(socket, :index, params)
    else
      socket
    end
  end
end
