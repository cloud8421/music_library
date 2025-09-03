defmodule MusicLibraryWeb.PaginationComponent do
  use MusicLibraryWeb, :html

  attr :pagination_params, :map, required: true
  attr :id, :atom, required: true

  def pagination(assigns) do
    page_links = generate_page_links(assigns.pagination_params)
    assigns = assign(assigns, :page_links, page_links)

    ~H"""
    <%!-- TODO: replace with OSS version --%>
    <div
      :if={@page_links.total_pages > 1}
      id={@id}
      class="flex items-center justify-between px-4 py-6 mb-4"
    >
      <%!-- Only on smallest viewport --%>
      <div class={[
        "flex flex-1 sm:hidden",
        justify_content(@page_links.prev_page, @page_links.next_page)
      ]}>
        <.button
          :if={@page_links.prev_page}
          patch={"?" <> encode_query(page: @page_links.prev_page, page_size: @pagination_params.page_size, query: @pagination_params.query, order: @pagination_params.order)}
          phx-click={JS.dispatch("music_library:scroll_top")}
        >
          {gettext("Previous")}
        </.button>
        <.button
          :if={@page_links.next_page}
          patch={"?" <> encode_query(page: @page_links.next_page, page_size: @pagination_params.page_size, query: @pagination_params.query, order: @pagination_params.order)}
          phx-click={JS.dispatch("music_library:scroll_top")}
        >
          {gettext("Next")}
        </.button>
      </div>
      <div class="hidden sm:flex sm:flex-1 sm:items-center sm:justify-items-center sm:justify-center">
        <div>
          <.button_group>
            <.prev_link
              :if={@page_links.prev_page}
              page_number={@page_links.prev_page}
              page_size={@pagination_params.page_size}
              query={@pagination_params.query}
              order={@pagination_params.order}
            />
            <.numbered_link
              :for={page_number <- @page_links.visible_left_pages}
              page_number={page_number}
              page_size={@pagination_params.page_size}
              query={@pagination_params.query}
              order={@pagination_params.order}
            />
            <.ellipsis :if={@page_links.left_ellipsis} />
            <.numbered_link
              :for={page_number <- @page_links.middle_pages}
              page_number={page_number}
              active={page_number == @pagination_params.page}
              page_size={@pagination_params.page_size}
              query={@pagination_params.query}
              order={@pagination_params.order}
            />
            <.ellipsis :if={@page_links.right_ellipsis} />
            <.numbered_link
              :for={page_number <- @page_links.visible_right_pages}
              page_number={page_number}
              page_size={@pagination_params.page_size}
              query={@pagination_params.query}
              order={@pagination_params.order}
            />
            <.next_link
              :if={@page_links.next_page}
              page_number={@page_links.next_page}
              page_size={@pagination_params.page_size}
              query={@pagination_params.query}
              order={@pagination_params.order}
            />
          </.button_group>
        </div>
      </div>
    </div>
    """
  end

  defp justify_content(nil, _next_page), do: "justify-end"
  defp justify_content(_prev_page, nil), do: "justify-start"
  defp justify_content(_prev_page, _next_page), do: "justify-between"

  attr :page_number, :integer, required: true
  attr :page_size, :integer, required: true
  attr :query, :string, required: true

  attr :order, :atom,
    values: [:alphabetical, :purchase, :scrobbled_at, :title, :artist, :album],
    required: true

  defp next_link(assigns) do
    ~H"""
    <.button
      phx-click={JS.dispatch("music_library:scroll_top")}
      patch={"?" <> encode_query(page: @page_number, page_size: @page_size, query: @query, order: @order)}
    >
      <span class="sr-only">{gettext("Next")}</span>
      <.icon name="hero-chevron-right" class="icon" aria-hidden="true" data-slot="icon" />
    </.button>
    """
  end

  attr :page_number, :integer, required: true
  attr :page_size, :integer, required: true
  attr :query, :string, required: true

  attr :order, :atom,
    values: [:alphabetical, :purchase, :scrobbled_at, :title, :artist, :album],
    required: true

  defp prev_link(assigns) do
    ~H"""
    <.button
      phx-click={JS.dispatch("music_library:scroll_top")}
      patch={"?" <> encode_query(page: @page_number, page_size: @page_size, query: @query, order: @order)}
    >
      <span class="sr-only">{gettext("Previous")}</span>
      <.icon name="hero-chevron-left" class="icon" aria-hidden="true" data-slot="icon" />
    </.button>
    """
  end

  defp ellipsis(assigns) do
    ~H"""
    <.button disabled>
      ...
    </.button>
    """
  end

  attr :page_number, :integer, required: true
  attr :page_size, :integer, required: true
  attr :active, :boolean, default: false
  attr :query, :string, required: true

  attr :order, :atom,
    values: [:alphabetical, :purchase, :scrobbled_at, :title, :artist, :album],
    required: true

  defp numbered_link(assigns) when assigns.active do
    ~H"""
    <.button class="!bg-zinc-100 dark:!bg-zinc-700">
      {@page_number}
    </.button>
    """
  end

  defp numbered_link(assigns) do
    ~H"""
    <.button
      phx-click={JS.dispatch("music_library:scroll_top")}
      patch={"?" <> encode_query(page: @page_number, page_size: @page_size, query: @query, order: @order)}
    >
      {@page_number}
    </.button>
    """
  end

  def page_to_offset(page, per_page) do
    (page - 1) * per_page
  end

  defp total_pages(total_entries, page_size) do
    without_remainder = div(total_entries, page_size)

    if rem(total_entries, page_size) == 0 do
      without_remainder
    else
      without_remainder + 1
    end
  end

  defp encode_query(params) do
    params
    |> Enum.filter(fn {_, v} -> v not in ["", nil] end)
    |> URI.encode_query()
  end

  @visible_left_pages 3
  @visible_right_pages 3
  @middle "..."
  defp generate_page_links(pagination_params) do
    %{
      total_entries: total_entries,
      page: page,
      page_size: page_size
    } = pagination_params

    total_pages = total_pages(total_entries, page_size)

    all_pages =
      case total_pages do
        0 -> []
        other -> Enum.to_list(1..other)
      end

    {left_pages, middle_pages, right_pages} =
      Enum.reduce(all_pages, {[], [], []}, fn p, {left_p, middle_p, right_p} ->
        cond do
          p < page - 2 ->
            {left_p ++ [p], middle_p, right_p}

          p > page + 2 ->
            {left_p, middle_p, right_p ++ [p]}

          true ->
            {left_p, middle_p ++ [p], right_p}
        end
      end)

    prev_page = if page > 1, do: page - 1
    next_page = if page < total_pages, do: page + 1

    left_ellipsis = if Enum.count(left_pages) > @visible_left_pages, do: @middle
    right_ellipsis = if Enum.count(right_pages) > @visible_right_pages, do: @middle

    visible_left_pages = Enum.take(left_pages, @visible_left_pages)
    visible_right_pages = Enum.take(right_pages, -@visible_right_pages)

    %{
      query: pagination_params.query,
      total_pages: total_pages,
      prev_page: prev_page,
      visible_left_pages: visible_left_pages,
      left_ellipsis: left_ellipsis,
      middle_pages: middle_pages,
      right_ellipsis: right_ellipsis,
      visible_right_pages: visible_right_pages,
      next_page: next_page
    }
  end
end
