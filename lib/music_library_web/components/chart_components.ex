defmodule MusicLibraryWeb.ChartComponents do
  @moduledoc """
  Chart components for the stats dashboard.
  """

  use MusicLibraryWeb, :live_component

  @doc """
  Renders a horizontal bar chart using CSS Grid.

  The label column auto-sizes to the widest label (up to 130px max),
  bars fill remaining space proportionally, and values are displayed
  to the right of each bar.

  ## Examples

      <.horizontal_bar_chart
        data={[{"Artist 1", 5}, {"Artist 2", 3}]}
        label_fn={&elem(&1, 0)}
        value_fn={&elem(&1, 1)}
        color_class="bg-red-500"
      />
  """
  attr :data, :list, required: true
  attr :label_fn, :any, required: true
  attr :value_fn, :any, required: true
  attr :color_class, :string, required: true
  attr :class, :string, default: ""
  attr :datum_click, :any, default: nil, doc: "the function for handling phx-click on each datum"

  def horizontal_bar_chart(assigns) when assigns.data != [] do
    assigns =
      assigns
      |> assign(:max_value, max_value(assigns.data, assigns.value_fn))

    ~H"""
    <div class={["w-full p-4", @class]}>
      <div class="grid grid-cols-[auto_1fr_auto] items-center gap-x-2 gap-y-1.5">
        <%= for datum <- @data do %>
          <% percentage = bar_percentage(@value_fn.(datum), @max_value) %>
          <% label = to_string(@label_fn.(datum)) %>

          <%= if @datum_click do %>
            <div
              class="group col-span-3 grid cursor-pointer grid-cols-subgrid items-center"
              phx-click={@datum_click.(datum)}
            >
              <.bar_row
                label={label}
                percentage={percentage}
                value={@value_fn.(datum)}
                color_class={@color_class}
                grouped
              />
            </div>
          <% else %>
            <.bar_row
              label={label}
              percentage={percentage}
              value={@value_fn.(datum)}
              color_class={@color_class}
            />
          <% end %>
        <% end %>
      </div>
    </div>
    """
  end

  def horizontal_bar_chart(assigns) do
    ~H"""
    <div class={["w-full", @class]}>
      {gettext("No data available")}
    </div>
    """
  end

  @doc """
  Renders a vertical bar chart using CSS Grid.

  Columns flow horizontally, use a fixed-height plotting area, and scroll on
  narrow screens while keeping labels and values visible.

  ## Examples

      <.vertical_bar_chart
        data={[{"May 01", 5}, {"May 02", 3}]}
        label_fn={&elem(&1, 0)}
        value_fn={&elem(&1, 1)}
        color_class="bg-emerald-500 dark:bg-emerald-400"
      />
  """
  attr :data, :list, required: true
  attr :label_fn, :any, required: true
  attr :value_fn, :any, required: true
  attr :color_class, :string, required: true
  attr :class, :string, default: ""
  attr :datum_click, :any, default: nil, doc: "the function for handling phx-click on each datum"

  def vertical_bar_chart(assigns) when assigns.data != [] do
    assigns =
      assigns
      |> assign(:max_value, max_value(assigns.data, assigns.value_fn))

    ~H"""
    <div class={["w-full overflow-x-auto p-4", @class]}>
      <div class="grid min-w-full grid-flow-col auto-cols-[minmax(1.75rem,1fr)] items-end gap-2">
        <%= for datum <- @data do %>
          <% percentage = bar_percentage(@value_fn.(datum), @max_value) %>
          <% label = to_string(@label_fn.(datum)) %>

          <%= if @datum_click do %>
            <div
              class="group flex h-72 cursor-pointer flex-col items-center justify-end gap-2"
              phx-click={@datum_click.(datum)}
            >
              <.vertical_bar_column
                label={label}
                percentage={percentage}
                value={@value_fn.(datum)}
                color_class={@color_class}
                grouped
              />
            </div>
          <% else %>
            <div class="flex h-72 flex-col items-center justify-end gap-2">
              <.vertical_bar_column
                label={label}
                percentage={percentage}
                value={@value_fn.(datum)}
                color_class={@color_class}
              />
            </div>
          <% end %>
        <% end %>
      </div>
    </div>
    """
  end

  def vertical_bar_chart(assigns) do
    ~H"""
    <div class={["w-full", @class]}>
      {gettext("No data available")}
    </div>
    """
  end

  attr :label, :string, required: true
  attr :percentage, :float, required: true
  attr :value, :any, required: true
  attr :color_class, :string, required: true
  attr :grouped, :boolean, default: false

  defp bar_row(assigns) do
    ~H"""
    <div
      class={[
        "max-w-[130px] truncate text-right text-xs font-medium",
        "text-zinc-500 dark:text-zinc-400",
        if(@grouped, do: "group-hover:text-zinc-700 dark:group-hover:text-zinc-200")
      ]}
      title={@label}
    >
      {@label}
    </div>
    <div class="h-5 rounded bg-zinc-200 dark:bg-zinc-700">
      <div
        class={[
          "h-full rounded opacity-80 transition-opacity",
          @color_class,
          if(@grouped, do: "group-hover:opacity-100")
        ]}
        style={"width: #{@percentage}%"}
      >
      </div>
    </div>
    <div class="text-xs font-semibold text-zinc-500 dark:text-zinc-400">
      {@value}
    </div>
    """
  end

  attr :label, :string, required: true
  attr :percentage, :float, required: true
  attr :value, :any, required: true
  attr :color_class, :string, required: true
  attr :grouped, :boolean, default: false

  defp vertical_bar_column(assigns) do
    ~H"""
    <div class="shrink-0 text-xs font-semibold text-zinc-500 dark:text-zinc-400">
      {@value}
    </div>
    <div
      class="flex h-36 w-full shrink-0 items-end rounded bg-zinc-200 dark:bg-zinc-700"
      title={"#{@label}: #{@value}"}
      aria-label={"#{@label}: #{@value}"}
      data-chart-label={@label}
      data-chart-value={@value}
    >
      <div
        class={[
          "w-full rounded-t opacity-80 transition-opacity",
          @color_class,
          if(@grouped, do: "group-hover:opacity-100")
        ]}
        style={"height: #{@percentage}%"}
      >
      </div>
    </div>
    <div class="relative h-20 w-full shrink-0 overflow-visible">
      <div
        class={[
          "absolute top-6 left-1/2 w-16 origin-center -translate-x-1/2 -rotate-90 text-center text-xs font-medium whitespace-nowrap",
          "text-zinc-500 dark:text-zinc-400",
          if(@grouped, do: "group-hover:text-zinc-700 dark:group-hover:text-zinc-200")
        ]}
        title={@label}
      >
        {@label}
      </div>
    </div>
    """
  end

  defp max_value(data, value_fn) do
    max = Enum.max_by(data, value_fn)
    value_fn.(max)
  end

  defp bar_percentage(_value, max_value) when max_value == 0, do: 0.0
  defp bar_percentage(value, max_value), do: value / max_value * 100
end
