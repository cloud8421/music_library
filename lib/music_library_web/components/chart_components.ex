defmodule MusicLibraryWeb.ChartComponents do
  use Phoenix.Component

  @doc """
  Renders a horizontal bar chart.

  ## Examples
      <.vertical_bar_chart
        data={[{"Artist 1", 5}, {"Artist 2", 3}]}
        width={400}
        height={300}
        bar_color="rgb(79, 70, 229)"
      />
  """
  attr :data, :list, required: true, doc: "List of {label, value} tuples"
  attr :width, :integer, default: 400
  attr :height, :integer, default: 300
  attr :bar_color, :string, default: "rgb(79, 70, 229)"
  attr :class, :string, default: ""
  attr :label_click, :any, default: nil, doc: "the function for handling phx-click on each label"

  def vertical_bar_chart(assigns) do
    assigns =
      assigns
      |> assign(:padding, 40)
      |> assign(:max_value, max_value(assigns.data))
      # Account for labels
      |> assign(:chart_width, assigns.width - 150)
      # Account for bottom padding
      |> assign(:chart_height, assigns.height - 40)
      |> assign(:bar_height, calculate_bar_height(assigns.data, assigns.height - 40))

    ~H"""
    <svg class={@class} width={@width} height={@height}>
      <%!-- X-axis labels and lines --%>
      <%= for {value, x} <- x_axis_values(@max_value, @chart_width) do %>
        <text
          x={x + 150}
          y={@height - 10}
          text-anchor="middle"
          class="text-xs fill-zinc-500 dark:fill-zinc-400"
        >
          {value}
        </text>
        <line
          x1={x + 150}
          y1={@padding / 2}
          x2={x + 150}
          y2={@height - @padding / 2}
          stroke="rgb(228, 228, 231)"
          stroke-width="1"
          stroke-dasharray="4,4"
        />
      <% end %>

      <%!-- Bars and labels --%>
      <%= for {{label, value}, index} <- Enum.with_index(@data) do %>
        <% bar_width = @chart_width * value / @max_value %>
        <% y = @padding / 2 + index * (@bar_height + 4) %>

        <%!-- Label --%>
        <text
          x="140"
          y={y + @bar_height / 2 + 4}
          text-anchor="end"
          class={["text-xs fill-zinc-500 dark:fill-zinc-400", @label_click && "cursor-pointer"]}
          phx-click={@label_click && @label_click.(label)}
        >
          {truncate_label(label, 20)}
        </text>

        <%!-- Bar --%>
        <rect
          x="150"
          y={y}
          width={bar_width}
          height={@bar_height}
          fill={@bar_color}
          class="opacity-80 hover:opacity-100 transition-opacity"
        >
          <title>{label}: {value}</title>
        </rect>

        <%!-- Value label --%>
        <text
          x={150 + bar_width + 5}
          y={y + @bar_height / 2 + 4}
          class="text-xs fill-zinc-500 dark:fill-zinc-400"
        >
          {value}
        </text>
      <% end %>
    </svg>
    """
  end

  defp max_value(data) do
    {_, max} = Enum.max_by(data, fn {_, value} -> value end)
    max
  end

  defp calculate_bar_height(data, available_height) do
    bar_count = length(data)
    max_height = min(30, (available_height - (bar_count - 1) * 4) / bar_count)
    max(20, max_height) |> trunc()
  end

  defp x_axis_values(max_value, width) do
    step = max_value / 5

    0..5
    |> Enum.map(fn i ->
      value = i * step
      x = i * width / 5
      {trunc(value), trunc(x)}
    end)
  end

  defp truncate_label(label, max_length) when byte_size(label) > max_length do
    String.slice(label, 0, max_length - 2) <> ".."
  end

  defp truncate_label(label, _), do: label
end
