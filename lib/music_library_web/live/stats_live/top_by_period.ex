defmodule MusicLibraryWeb.StatsLive.TopByPeriod do
  use MusicLibraryWeb, :live_component

  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :key, :atom, required: true
  attr :fetch_fn, :any, required: true
  attr :timezone, :string, required: true
  attr :last_updated_uts, :any

  slot :item, required: true

  def live(assigns) do
    ~H"""
    <.live_component module={__MODULE__} {assigns} id={@id} />
    """
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mt-5">
      <.tabs>
        <div class="flex justify-between">
          <h1 class="text-base font-semibold text-zinc-900 lg:text-2xl dark:text-zinc-200">
            {@title}
          </h1>
          <.tabs_list active_tab={name_from_period(@key, @period)} variant="segmented" size="xs">
            <:tab
              class="flex-1"
              name={"#{@key}_last_7_days"}
              phx-click={JS.push("set_period", value: %{period: "last_7_days"})}
              phx-target={@myself}
            >
              {gettext("7d")}
            </:tab>
            <:tab
              class="flex-1"
              name={"#{@key}_last_30_days"}
              phx-click={JS.push("set_period", value: %{period: "last_30_days"})}
              phx-target={@myself}
            >
              {gettext("30d")}
            </:tab>
            <:tab
              class="flex-1"
              name={"#{@key}_last_90_days"}
              phx-click={JS.push("set_period", value: %{period: "last_90_days"})}
              phx-target={@myself}
            >
              {gettext("90d")}
            </:tab>
            <:tab
              class="flex-1"
              name={"#{@key}_last_365_days"}
              phx-click={JS.push("set_period", value: %{period: "last_365_days"})}
              phx-target={@myself}
            >
              {gettext("1y")}
            </:tab>
            <:tab
              class="flex-1"
              name={"#{@key}_all_time"}
              phx-click={JS.push("set_period", value: %{period: "all_time"})}
              phx-target={@myself}
            >
              {gettext("∞")}
            </:tab>
          </.tabs_list>
        </div>
        <.async_result :let={items} assign={assigns[@key]}>
          <:loading>
            <div class="flex h-182 items-center justify-center">
              <.loading />
            </div>
          </:loading>
          <div class="mt-4 rounded-md bg-white p-4 shadow-sm dark:bg-zinc-800">
            <div class="space-y-2">
              {render_slot(@item, items)}
            </div>
          </div>
        </.async_result>
      </.tabs>
    </div>
    """
  end

  defp name_from_period(key, period), do: "#{key}_#{period}"

  @impl true
  def mount(socket) do
    {:ok, assign(socket, :period, :last_7_days)}
  end

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_data()}
  end

  @impl true
  def handle_event("set_period", %{"period" => period}, socket) do
    {:noreply,
     socket
     |> assign(:period, String.to_existing_atom(period))
     |> assign_data()}
  end

  defp assign_data(socket) do
    %{timezone: timezone, period: period, key: key, fetch_fn: fetch_fn} = socket.assigns
    current_time = DateTime.utc_now()

    assign_async(
      socket,
      key,
      fn ->
        items =
          fetch_fn.(
            limit: 10,
            current_time: current_time,
            timezone: timezone,
            period: period
          )

        {:ok, %{key => items}}
      end,
      reset: true
    )
  end
end
