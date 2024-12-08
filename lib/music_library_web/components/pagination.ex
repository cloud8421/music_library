defmodule MusicLibraryWeb.Pagination do
  use Phoenix.Component
  use Gettext, backend: MusicLibraryWeb.Gettext

  alias Phoenix.LiveView.JS

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
        <.link
          :if={@page_links.prev_page}
          patch={"?" <> encode_query(page: @page_links.prev_page, page_size: @pagination_params.page_size, query: @pagination_params.query)}
          class={[
            "relative inline-flex items-center rounded-md border",
            "px-3 py-2 text-sm font-medium",
            "bg-zinc-900 hover:bg-zinc-700 dark:bg-zinc-100 dark:hover:bg-zinc-400",
            "text-white active:text-white/80 dark:text-zinc-900 dark:active:text-zinc-900/80",
            "focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-zinc-600"
          ]}
        >
          {gettext("Previous")}
        </.link>
        <.link
          :if={@page_links.next_page}
          patch={"?" <> encode_query(page: @page_links.next_page, page_size: @pagination_params.page_size, query: @pagination_params.query)}
          class={[
            "relative ml-3 inline-flex items-center rounded-md border",
            "px-3 py-2 text-sm font-medium",
            "bg-zinc-900 hover:bg-zinc-700 dark:bg-zinc-100 dark:hover:bg-zinc-400",
            "text-white active:text-white/80 dark:text-zinc-900 dark:active:text-zinc-900/80",
            "focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-zinc-600"
          ]}
        >
          {gettext("Next")}
        </.link>
      </div>
      <div class="hidden sm:flex sm:flex-1 sm:items-center sm:justify-items-center sm:justify-center">
        <div>
          <nav class="isolate inline-flex -space-x-px rounded-md shadow-sm" aria-label="Pagination">
            <.prev_link
              :if={@page_links.prev_page}
              page_number={@page_links.prev_page}
              page_size={@pagination_params.page_size}
              query={@pagination_params.query}
            />
            <.numbered_link
              :for={page_number <- @page_links.visible_left_pages}
              page_number={page_number}
              page_size={@pagination_params.page_size}
              query={@pagination_params.query}
            />
            <.separator :if={@page_links.left_separator} />
            <.numbered_link
              :for={page_number <- @page_links.middle_pages}
              page_number={page_number}
              active={page_number == @pagination_params.page}
              page_size={@pagination_params.page_size}
              query={@pagination_params.query}
            />
            <.separator :if={@page_links.right_separator} />
            <.numbered_link
              :for={page_number <- @page_links.visible_right_pages}
              page_number={page_number}
              page_size={@pagination_params.page_size}
              query={@pagination_params.query}
            />
            <.next_link
              :if={@page_links.next_page}
              page_number={@page_links.next_page}
              page_size={@pagination_params.page_size}
              query={@pagination_params.query}
            />
          </nav>
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

  defp next_link(assigns) do
    ~H"""
    <.link
      class={[
        "relative inline-flex items-center rounded-r-md px-2 py-2",
        "text-zinc-400 ring-1 ring-inset ring-zinc-300 hover:bg-zinc-50 focus:z-20 focus:outline-offset-0"
      ]}
      phx-click={JS.dispatch("music_library:scroll_top")}
      patch={"?" <> encode_query(page: @page_number, page_size: @page_size, query: @query)}
    >
      <span class="sr-only">{gettext("Next")}</span>
      <svg class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
        <path
          fill-rule="evenodd"
          d="M7.21 14.77a.75.75 0 01.02-1.06L11.168 10 7.23 6.29a.75.75 0 111.04-1.08l4.5 4.25a.75.75 0 010 1.08l-4.5 4.25a.75.75 0 01-1.06-.02z"
          clip-rule="evenodd"
        />
      </svg>
    </.link>
    """
  end

  attr :page_number, :integer, required: true
  attr :page_size, :integer, required: true
  attr :query, :string, required: true

  defp prev_link(assigns) do
    ~H"""
    <.link
      class="relative inline-flex items-center rounded-l-md px-2 py-2 text-zinc-400 ring-1 ring-inset ring-zinc-300 hover:bg-zinc-50 focus:z-20 focus:outline-offset-0"
      phx-click={JS.dispatch("music_library:scroll_top")}
      patch={"?" <> encode_query(page: @page_number, page_size: @page_size, query: @query)}
    >
      <span class="sr-only">{gettext("Previous")}</span>
      <svg class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
        <path
          fill-rule="evenodd"
          d="M12.79 5.23a.75.75 0 01-.02 1.06L8.832 10l3.938 3.71a.75.75 0 11-1.04 1.08l-4.5-4.25a.75.75 0 010-1.08l4.5-4.25a.75.75 0 011.06.02z"
          clip-rule="evenodd"
        />
      </svg>
    </.link>
    """
  end

  defp separator(assigns) do
    ~H"""
    <span class="relative hidden items-center px-4 py-2 text-sm font-semibold text-zinc-900 dark:text-zinc-400 ring-1 ring-inset ring-zinc-300 focus:z-20 focus:outline-offset-0 md:inline-flex">
      ...
    </span>
    """
  end

  attr :page_number, :integer, required: true
  attr :page_size, :integer, required: true
  attr :active, :boolean, default: false
  attr :query, :string, required: true

  defp numbered_link(assigns) when assigns.active do
    ~H"""
    <span class="relative z-10 inline-flex items-center first:rounded-l-md last:rounded-r-md bg-zinc-600 dark:bg-zinc-300 px-4 py-2 text-sm font-semibold text-white dark:text-zinc-700 focus:z-20 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-zinc-600">
      {@page_number}
    </span>
    """
  end

  defp numbered_link(assigns) do
    ~H"""
    <.link
      class="relative hidden items-center first:rounded-l-md last:rounded-r-md px-4 py-2 text-sm font-semibold text-zinc-900 dark:text-zinc-400 ring-1 ring-inset ring-zinc-300 hover:bg-zinc-300 hover:text-zinc-500 focus:z-20 focus:outline-offset-0 md:inline-flex"
      phx-click={JS.dispatch("music_library:scroll_top")}
      patch={"?" <> encode_query(page: @page_number, page_size: @page_size, query: @query)}
    >
      {@page_number}
    </.link>
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
    all_pages = Enum.to_list(1..total_pages)

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

    left_separator = if Enum.count(left_pages) > @visible_left_pages, do: @middle
    right_separator = if Enum.count(right_pages) > @visible_right_pages, do: @middle

    visible_left_pages = Enum.take(left_pages, @visible_left_pages)
    visible_right_pages = Enum.take(right_pages, -@visible_right_pages)

    %{
      query: pagination_params.query,
      total_pages: total_pages,
      prev_page: prev_page,
      visible_left_pages: visible_left_pages,
      left_separator: left_separator,
      middle_pages: middle_pages,
      right_separator: right_separator,
      visible_right_pages: visible_right_pages,
      next_page: next_page
    }
  end
end
