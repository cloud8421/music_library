defmodule MusicLibraryWeb.Pagination do
  use Phoenix.Component

  # alias Phoenix.LiveView.JS
  use Gettext, backend: MusicLibraryWeb.Gettext

  attr :pagination_params, :map, required: true

  def pagination(assigns) do
    page_links = generate_page_links(assigns.pagination_params)
    assigns = assign(assigns, :page_links, page_links)

    ~H"""
    <div class="flex items-center justify-between border-t border-gray-200 bg-white px-4 py-3 sm:px-6">
      <%!-- Only on smallest viewport --%>
      <div class="flex flex-1 justify-between sm:hidden">
        <a
          :if={@page_links.prev_page}
          href="#"
          class="relative inline-flex items-center rounded-md border border-gray-300 bg-white px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50"
        >
          Previous
        </a>
        <a
          :if={@page_links.next_page}
          href="#"
          class="relative ml-3 inline-flex items-center rounded-md border border-gray-300 bg-white px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50"
        >
          Next
        </a>
      </div>
      <div class="hidden sm:flex sm:flex-1 sm:items-center sm:justify-items-center sm:justify-center">
        <div>
          <nav class="isolate inline-flex -space-x-px rounded-md shadow-sm" aria-label="Pagination">
            <.prev_link
              :if={@page_links.prev_page}
              page_number={@page_links.prev_page}
              page_size={@pagination_params.page_size}
            />
            <.numbered_link
              :for={page_number <- @page_links.visible_left_pages}
              page_number={page_number}
              page_size={@pagination_params.page_size}
            />
            <.separator :if={@page_links.left_separator} />
            <.numbered_link
              :for={page_number <- @page_links.middle_pages}
              page_number={page_number}
              active={page_number == @pagination_params.page}
              page_size={@pagination_params.page_size}
            />
            <.separator :if={@page_links.right_separator} />
            <.numbered_link
              :for={page_number <- @page_links.visible_right_pages}
              page_number={page_number}
              page_size={@pagination_params.page_size}
            />
            <.next_link
              :if={@page_links.next_page}
              page_number={@page_links.next_page}
              page_size={@pagination_params.page_size}
            />
          </nav>
        </div>
      </div>
    </div>
    """
  end

  attr :page_number, :integer, required: true
  attr :page_size, :integer, required: true

  defp next_link(assigns) do
    ~H"""
    <.link
      class="relative inline-flex items-center rounded-r-md px-2 py-2 text-gray-400 ring-1 ring-inset ring-gray-300 hover:bg-gray-50 focus:z-20 focus:outline-offset-0"
      patch={"?" <> URI.encode_query(page: @page_number, page_size: @page_size)}
    >
      <span class="sr-only">Next</span>
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

  defp prev_link(assigns) do
    ~H"""
    <.link
      class="relative inline-flex items-center rounded-l-md px-2 py-2 text-gray-400 ring-1 ring-inset ring-gray-300 hover:bg-gray-50 focus:z-20 focus:outline-offset-0"
      patch={"?" <> URI.encode_query(page: @page_number, page_size: @page_size)}
    >
      <span class="sr-only">Previous</span>
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
    <span class="relative hidden items-center px-4 py-2 text-sm font-semibold text-gray-900 ring-1 ring-inset ring-gray-300 hover:bg-gray-50 focus:z-20 focus:outline-offset-0 md:inline-flex">
      ...
    </span>
    """
  end

  attr :page_number, :integer, required: true
  attr :page_size, :integer, required: true
  attr :active, :boolean, default: false

  defp numbered_link(assigns) when assigns.active do
    ~H"""
    <span class="relative z-10 inline-flex items-center first:rounded-l-md last:rounded-r-md bg-indigo-600 px-4 py-2 text-sm font-semibold text-white focus:z-20 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600">
      <%= @page_number %>
    </span>
    """
  end

  defp numbered_link(assigns) do
    ~H"""
    <.link
      class="relative hidden items-center first:rounded-l-md last:rounded-r-md px-4 py-2 text-sm font-semibold text-gray-900 ring-1 ring-inset ring-gray-300 hover:bg-gray-50 focus:z-20 focus:outline-offset-0 md:inline-flex"
      patch={"?" <> URI.encode_query(page: @page_number, page_size: @page_size)}
    >
      <%= @page_number %>
    </.link>
    """
  end

  def get_pagination_params(params, total_records) do
    %{
      total_entries: total_records,
      page: parse_int_or_default(params["page"], 1),
      page_size: parse_int_or_default(params["page_size"], 20)
    }
  end

  def page_to_offset(page, per_page) do
    (page - 1) * per_page
  end

  defp parse_int_or_default(nil, default), do: default

  defp parse_int_or_default(value, _default) when is_binary(value) do
    String.to_integer(value)
  end

  defp total_pages(total_entries, page_size) do
    without_remainder = div(total_entries, page_size)

    if rem(total_entries, page_size) == 0 do
      without_remainder
    else
      without_remainder + 1
    end
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
