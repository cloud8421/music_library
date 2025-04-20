defmodule MusicLibraryWeb.ChartComponents do
  use MusicLibraryWeb, :live_component

  @doc """
  Renders a horizontal bar chart.

  ## Examples
      <.vertical_bar_chart
        data={[{"Artist 1", 5}, {"Artist 2", 3}]}
        label_fn={&elem(&1, 0)}
        value_fn={&elem(&1, 1)}
        width={400}
        height={300}
        color_class="fill-red-500"
      />
  """
  attr :data, :list, required: true
  attr :label_fn, :any, required: true
  attr :value_fn, :any, required: true
  attr :width, :integer, default: 400
  attr :height, :integer, default: 300
  attr :color_class, :string, required: true
  attr :class, :string, default: ""
  attr :label_click, :any, default: nil, doc: "the function for handling phx-click on each label"

  def vertical_bar_chart(assigns) do
    assigns =
      assigns
      |> assign(:padding, 40)
      |> assign(:max_value, max_value(assigns.data, assigns.value_fn))
      # Account for labels and padding
      |> assign(:chart_width, assigns.width - 150 - 40)
      # Account for bottom padding
      |> assign(:chart_height, assigns.height - 40)
      |> assign(:bar_height, calculate_bar_height(assigns.data, assigns.height - 40))

    ~H"""
    <div class={["w-full", @class]}>
      <svg
        viewBox={"0 0 #{@width} #{@height}"}
        preserveAspectRatio="xMidYMid meet"
        class="w-full h-full"
      >
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
        <%= for {datum, index} <- Enum.with_index(@data) do %>
          <% bar_width = @chart_width * @value_fn.(datum) / @max_value %>
          <% y = @padding / 2 + index * (@bar_height + 4) %>

          <%!-- Label --%>
          <text
            x="140"
            y={y + @bar_height / 2 + 4}
            text-anchor="end"
            class={["text-xs fill-zinc-500 dark:fill-zinc-400", @label_click && "cursor-pointer"]}
            phx-click={@label_click && @label_click.(datum)}
          >
            {truncate_label(@label_fn.(datum), 20)}
          </text>

          <%!-- Bar --%>
          <rect
            x="150"
            y={y}
            width={bar_width}
            height={@bar_height}
            class={["opacity-80 hover:opacity-100 transition-opacity", @color_class]}
          >
            <title>{@label_fn.(datum)}: {@value_fn.(datum)}</title>
          </rect>

          <%!-- Value label --%>
          <text
            x={150 + bar_width + 5}
            y={y + @bar_height / 2 + 4}
            class="text-xs fill-zinc-500 dark:fill-zinc-400"
          >
            {@value_fn.(datum)}
          </text>
        <% end %>
      </svg>
    </div>
    """
  end

  defp max_value(data, value_fn) do
    max = Enum.max_by(data, value_fn)
    value_fn.(max)
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
