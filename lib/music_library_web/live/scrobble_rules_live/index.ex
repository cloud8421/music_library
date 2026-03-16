defmodule MusicLibraryWeb.ScrobbleRulesLive.Index do
  use MusicLibraryWeb, :live_view

  import MusicLibraryWeb.Components.Pagination
  import MusicLibraryWeb.LiveHelpers.Params

  alias MusicLibrary.ScrobbleRules
  alias MusicLibrary.ScrobbleRules.ScrobbleRule

  @default_list_params %{
    page: 1,
    page_size: 50,
    query: "",
    order: :inserted_at
  }

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_section={@current_section} socket={@socket}>
      <header class="gap-6 mb-2">
        <div class="flex items-center justify-between gap-6 mb-2 mt-2">
          <.search_form query={@list_params.query} />
          <.button_group>
            <.button
              variant="solid"
              size="sm"
              patch={~p"/scrobble-rules/new"}
            >
              <.icon name="hero-plus" class="icon" aria-hidden="true" data-slot="icon" />
              {gettext("Add")}
            </.button>
            <.button
              variant="solid"
              size="sm"
              phx-click="apply_all_rules"
            >
              <.icon name="hero-play" class="icon" />
              {gettext("Apply")}
            </.button>
          </.button_group>
        </div>
      </header>

      <div class="flex items-end justify-between gap-6 mt-6">
        <.button_group>
          <.button
            patch={order_path(@list_params, :alphabetical)}
            size="sm"
            class={[
              @list_params.order == :alphabetical && "bg-zinc-100! dark:bg-zinc-700!"
            ]}
          >
            <.icon name="hero-user-solid" class="icon" aria-hidden="true" data-slot="icon" />
            <span class="sr-only sm:not-sr-only">{gettext("A->Z")}</span>
          </.button>
          <.button
            patch={order_path(@list_params, :inserted_at)}
            size="sm"
            class={[
              @list_params.order == :inserted_at && "bg-zinc-100! dark:bg-zinc-700!"
            ]}
          >
            <.icon name="hero-clock" class="icon" aria-hidden="true" data-slot="icon" />
            <span class="sr-only sm:not-sr-only">{gettext("Updated")}</span>
          </.button>
        </.button_group>
      </div>

      <div class="mt-6 space-y-4">
        <ul phx-update="stream" id="scrobble-rules-list" class="space-y-4">
          <li
            id="no-scrobble-rules"
            class="hidden only:block p-8 text-center bg-zinc-50 dark:bg-zinc-800 rounded-lg"
          >
            <.icon name="hero-beaker" class="h-12 w-12 text-zinc-400 mx-auto mb-4" />
            <p class="text-zinc-600 dark:text-zinc-400">
              {gettext("No scrobble rules found")}
            </p>
          </li>

          <li
            :for={{dom_id, scrobble_rule} <- @streams.scrobble_rules}
            id={dom_id}
            class="flex items-center gap-2"
          >
            <div class="grow min-w-0">
              <div class="lg:flex lg:items-center lg:gap-2">
                <p class="text-sm text-zinc-900 dark:text-zinc-100">
                  {scrobble_rule.match_value}
                </p>
                <p class="text-xs font-mono text-zinc-500 dark:text-zinc-400 mt-1 lg:mt-0 truncate">
                  {scrobble_rule.target_musicbrainz_id}
                </p>
              </div>
              <p
                :if={scrobble_rule.description}
                class="text-xs text-zinc-500 dark:text-zinc-400 mt-1 truncate"
              >
                {scrobble_rule.description}
              </p>
            </div>
            <div class="flex flex-col lg:flex-row items-end lg:items-center gap-1 lg:gap-2 shrink-0">
              <.type_badge type={scrobble_rule.type} />
              <.status_badge enabled={scrobble_rule.enabled} />
              <span class="text-xs text-zinc-500 dark:text-zinc-400 text-nowrap">
                {Calendar.strftime(scrobble_rule.inserted_at, "%Y-%m-%d")}
              </span>
            </div>
            <div class="flex items-center shrink-0">
              <.dropdown id={"actions-#{scrobble_rule.id}"} placement="bottom-end">
                <:toggle>
                  <.button variant="ghost">
                    <span class="sr-only">{gettext("Actions")}</span>
                    <.icon
                      name="hero-ellipsis-vertical"
                      class="h-5 w-5 text-zinc-500 dark:text-zinc-400 cursor-pointer"
                      aria-hidden="true"
                      data-slot="icon"
                    />
                  </.button>
                </:toggle>
                <.dropdown_button phx-click="apply_rule" phx-value-id={scrobble_rule.id}>
                  {gettext("Apply rule")}
                </.dropdown_button>
                <.dropdown_button phx-click="toggle_enabled" phx-value-id={scrobble_rule.id}>
                  {if scrobble_rule.enabled, do: gettext("Disable rule"), else: gettext("Enable rule")}
                </.dropdown_button>
                <.dropdown_link
                  id={"actions-#{scrobble_rule.id}-edit"}
                  patch={
                    ~p"/scrobble-rules/#{scrobble_rule}/edit?#{@list_params |> Map.take([:page, :page_size, :query]) |> Enum.filter(fn {_, v} -> v not in ["", nil] end)}"
                  }
                >
                  {gettext("Edit")}
                </.dropdown_link>
                <.separator />
                <.dropdown_button
                  phx-click="delete"
                  phx-value-id={scrobble_rule.id}
                  data-confirm={gettext("Are you sure?")}
                  class={[
                    "text-red-900! hover:bg-red-50! dark:text-red-500! dark:hover:bg-red-900/30! dark:hover:text-red-600!"
                  ]}
                >
                  {gettext("Delete")}
                </.dropdown_button>
              </.dropdown>
            </div>
          </li>
        </ul>

        <.pagination id={:bottom_pagination} pagination_params={@list_params} />
      </div>

      <.structured_modal
        :if={@live_action in [:new, :edit]}
        id="scrobble_rule-modal"
        on_close={JS.patch(back_path(@list_params))}
      >
        <.live_component
          module={MusicLibraryWeb.ScrobbleRulesLive.Form}
          id={@scrobble_rule.id || :new}
          title={@page_title}
          action={@live_action}
          scrobble_rule={@scrobble_rule}
          patch={back_path(@list_params)}
        />
      </.structured_modal>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :current_section, :scrobble_rules)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id} = params) do
    socket
    |> apply_fallback_index(params, :scrobble_rules, &apply_action/3)
    |> assign(:page_title, gettext("Edit Scrobble Rule"))
    |> assign(:scrobble_rule, ScrobbleRules.get_scrobble_rule!(id))
  end

  defp apply_action(socket, :new, params) do
    socket
    |> apply_fallback_index(params, :scrobble_rules, &apply_action/3)
    |> assign(:page_title, gettext("New Scrobble Rule"))
    |> assign(:scrobble_rule, %ScrobbleRule{})
  end

  defp apply_action(socket, :index, params) do
    query = params["query"]
    order = parse_order(params["order"] || "inserted_at")

    total_rules = ScrobbleRules.count_scrobble_rules(query: query)

    list_params =
      @default_list_params
      |> merge_query(query)
      |> merge_order(order)
      |> merge_pagination(params, total_rules)

    load_and_assign_rules(socket, list_params)
  end

  defp load_and_assign_rules(socket, list_params) do
    offset = page_to_offset(list_params.page, list_params.page_size)

    rules =
      ScrobbleRules.list_scrobble_rules(
        query: list_params.query,
        order: list_params.order,
        offset: offset,
        limit: list_params.page_size
      )

    socket
    |> assign(:list_params, list_params)
    |> assign(:page_title, gettext("Scrobble Rules"))
    |> assign(:scrobble_rule, nil)
    |> stream(:scrobble_rules, rules, reset: true)
  end

  def back_path(list_params) do
    qs =
      list_params
      |> Map.take([:page, :page_size, :query, :order])
      |> Enum.filter(fn {_, v} -> v not in ["", nil] end)

    ~p"/scrobble-rules?#{qs}"
  end

  @impl true
  def handle_info(
        {MusicLibraryWeb.ScrobbleRulesLive.Form, {:created, scrobble_rule}},
        socket
      ) do
    {:noreply,
     socket
     |> stream_insert(:scrobble_rules, scrobble_rule, at: 0)
     |> load_and_assign_rules(socket.assigns.list_params)}
  end

  def handle_info(
        {MusicLibraryWeb.ScrobbleRulesLive.Form, {:updated, scrobble_rule}},
        socket
      ) do
    {:noreply, stream_insert(socket, :scrobble_rules, scrobble_rule)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    scrobble_rule = ScrobbleRules.get_scrobble_rule!(id)
    {:ok, _} = ScrobbleRules.delete_scrobble_rule(scrobble_rule)

    {:noreply,
     socket
     |> stream_delete(:scrobble_rules, scrobble_rule)
     |> load_and_assign_rules(socket.assigns.list_params)}
  end

  @impl true
  def handle_event("toggle_enabled", %{"id" => id}, socket) do
    scrobble_rule = ScrobbleRules.get_scrobble_rule!(id)

    {:ok, updated_rule} =
      ScrobbleRules.update_scrobble_rule(scrobble_rule, %{enabled: !scrobble_rule.enabled})

    {:noreply, stream_insert(socket, :scrobble_rules, updated_rule)}
  end

  @impl true
  def handle_event("apply_rule", %{"id" => id}, socket) do
    scrobble_rule = ScrobbleRules.get_scrobble_rule!(id)

    case ScrobbleRules.apply_rule(scrobble_rule) do
      {:ok, count} ->
        message = gettext("Rule applied successfully. Updated %{count} tracks.", count: count)
        {:noreply, put_toast(socket, :info, message)}

      {:error, reason} ->
        message = gettext("Error applying rule: %{reason}", reason: reason)
        {:noreply, put_toast(socket, :error, message)}
    end
  end

  @impl true
  def handle_event("apply_all_rules", _params, socket) do
    results = ScrobbleRules.apply_all_rules()

    ScrobbleRules.log_apply_results(results)

    total_updated =
      results
      |> Enum.filter(fn {status, _} -> status == :ok end)
      |> Enum.map(fn {:ok, {_, _, count}} -> count end)
      |> Enum.sum()

    message =
      gettext("All rules applied successfully. Updated %{count} tracks total.",
        count: total_updated
      )

    {:noreply, put_toast(socket, :info, message)}
  end

  def handle_event("search", %{"query" => query}, socket) do
    qs =
      @default_list_params
      |> Map.put(:query, query)
      |> Map.put(:order, socket.assigns.list_params.order)
      |> Map.take([:query, :page, :page_size, :order])

    {:noreply, push_patch(socket, to: ~p"/scrobble-rules?#{qs}")}
  end

  defp parse_order("alphabetical"), do: :alphabetical
  defp parse_order(_), do: :inserted_at

  defp order_path(list_params, order) do
    qs =
      list_params
      |> Map.take([:query])
      |> Map.put(:order, order)
      |> Enum.filter(fn {_, v} -> v not in ["", nil] end)

    ~p"/scrobble-rules?#{qs}"
  end

  attr :type, :atom, required: true, values: [:album, :artist]

  defp type_badge(assigns) do
    ~H"""
    <.badge :if={@type == :album} color="danger">{gettext("Album")}</.badge>
    <.badge :if={@type == :artist} color="info">{gettext("Artist")}</.badge>
    """
  end

  attr :enabled, :boolean, required: true

  defp status_badge(assigns) do
    ~H"""
    <.badge :if={@enabled} color="success">{gettext("Enabled")}</.badge>
    <.badge :if={!@enabled} color="warning">{gettext("Disabled")}</.badge>
    """
  end
end
