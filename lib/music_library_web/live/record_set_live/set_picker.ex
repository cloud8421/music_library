defmodule MusicLibraryWeb.RecordSetLive.SetPicker do
  @moduledoc """
  Additive multi-set picker rendered inside a modal.

  Loads all record sets as lightweight choices and shows which sets the
  record already belongs to (checked, disabled). Selecting additional
  sets and submitting calls `MusicLibrary.RecordSets.add_record_to_sets/2`
  in one transactional bulk operation.
  """

  use MusicLibraryWeb, :live_component

  alias MusicLibrary.Records.Record
  alias MusicLibrary.RecordSets

  @impl true
  def update(%{record: %Record{id: record_id} = record} = assigns, socket) do
    socket =
      if Map.has_key?(socket.assigns, :record_id) && socket.assigns.record_id == record_id do
        # Same record: refresh ordinary assigns but keep pending selection
        socket
        |> assign(:record, record)
        |> assign(:close_path, assigns.close_path)
        |> assign(:title, assigns[:title] || gettext("Add to sets"))
      else
        # New or different record: full reinitialisation
        {choices, member_set_ids} = RecordSets.list_record_set_choices_for_record(record_id)

        socket
        |> assign(:record, record)
        |> assign(:record_id, record_id)
        |> assign(:close_path, assigns.close_path)
        |> assign(:title, assigns[:title] || gettext("Add to sets"))
        |> assign(:choices, choices)
        |> assign(:member_set_ids, member_set_ids)
        |> assign(:selected_ids, MapSet.new())
        |> assign(:error_message, nil)
        |> assign(:stale_message, nil)
      end

    {:ok, socket}
  end

  @impl true
  def handle_event("save", %{"set_ids" => _submitted_ids}, socket) do
    %{record: record, selected_ids: selected_ids, close_path: close_path} = socket.assigns
    set_ids = MapSet.to_list(selected_ids)

    if set_ids == [] do
      {:noreply, assign(socket, :error_message, gettext("Please select at least one set."))}
    else
      case RecordSets.add_record_to_sets(record, set_ids) do
        {:ok, 0} ->
          put_toast!(:info, gettext("Already in all selected sets."))

          {:noreply, push_patch(socket, to: close_path)}

        {:ok, 1} ->
          put_toast!(:info, gettext("Record added to 1 set."))

          {:noreply, push_patch(socket, to: close_path)}

        {:ok, count} ->
          put_toast!(
            :info,
            ngettext("Record added to 1 set.", "Record added to %{count} sets.", count,
              count: count
            )
          )

          {:noreply, push_patch(socket, to: close_path)}

        {:error, {:record_sets_not_found, _missing}} ->
          {choices, member_set_ids} =
            RecordSets.list_record_set_choices_for_record(record.id)

          valid_selected =
            selected_ids
            |> MapSet.to_list()
            |> Enum.filter(fn id ->
              Enum.any?(choices, &(&1.id == id))
            end)
            |> MapSet.new()

          {:noreply,
           socket
           |> assign(:choices, choices)
           |> assign(:member_set_ids, member_set_ids)
           |> assign(:selected_ids, valid_selected)
           |> assign(
             :stale_message,
             gettext("Some sets were deleted. Your selection has been updated.")
           )}

        {:error, :record_not_found} ->
          {:noreply,
           socket
           |> assign(:error_message, gettext("Record has been deleted."))
           |> assign(:selected_ids, MapSet.new())}

        {:error, :empty_selection} ->
          {:noreply, assign(socket, :error_message, gettext("Please select at least one set."))}
      end
    end
  end

  @impl true
  def handle_event("toggle", params, socket) do
    %{choices: choices, member_set_ids: member_set_ids} = socket.assigns

    # Fluxon checkbox_group sends selected values as a list under the group name.
    # Filter out any empty-string default and only accept IDs of sets the record
    # is NOT already a member of.
    submitted =
      (params["set_ids"] || [])
      |> Enum.reject(&(&1 == ""))

    selectable_ids =
      choices
      |> Enum.map(& &1.id)
      |> Enum.reject(&MapSet.member?(member_set_ids, &1))

    new_selected =
      submitted
      |> Enum.filter(&(&1 in selectable_ids))
      |> MapSet.new()

    {:noreply, assign(socket, selected_ids: new_selected, error_message: nil, stale_message: nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <h1 id="set-picker-heading" class="text-lg font-semibold text-zinc-900 dark:text-zinc-100">
        {@title}
      </h1>

      <p :if={@stale_message} class="mt-2 text-sm text-amber-600 dark:text-amber-400">
        {@stale_message}
      </p>

      <p :if={@error_message} class="mt-2 text-sm text-red-600 dark:text-red-400">
        {@error_message}
      </p>

      <%= if @choices == [] do %>
        <p class="mt-4 text-sm text-zinc-500 dark:text-zinc-400">
          {gettext("No record sets available. Create one first.")}
        </p>
      <% else %>
        <%= if MapSet.size(@member_set_ids) == length(@choices) do %>
          <p class="mt-4 text-sm text-zinc-500 dark:text-zinc-400">
            {gettext("This record already belongs to every set.")}
          </p>
        <% else %>
          <form
            id="set-picker-form"
            phx-change="toggle"
            phx-submit="save"
            phx-target={@myself}
            class="mt-4"
          >
            <div class="max-h-96 overflow-y-auto">
              <.checkbox_group id="set-picker-checkboxes" name="set_ids">
                <:checkbox
                  :for={choice <- @choices}
                  value={choice.id}
                  label={choice.name}
                  checked={
                    MapSet.member?(@member_set_ids, choice.id) or
                      MapSet.member?(@selected_ids, choice.id)
                  }
                  disabled={MapSet.member?(@member_set_ids, choice.id)}
                />
              </.checkbox_group>
            </div>

            <footer class="mt-6 flex items-center justify-between">
              <p class="text-sm text-zinc-500 dark:text-zinc-400">
                {ngettext(
                  "%{count} set selected",
                  "%{count} sets selected",
                  MapSet.size(@selected_ids),
                  count: MapSet.size(@selected_ids)
                )}
              </p>

              <.button
                type="submit"
                variant="solid"
                disabled={MapSet.size(@selected_ids) == 0}
                phx-disable-with={gettext("Adding...")}
              >
                <.icon name="hero-plus" class="icon" aria-hidden="true" data-slot="icon" />
                {gettext("Add to selected sets")}
              </.button>
            </footer>
          </form>
        <% end %>
      <% end %>
    </div>
    """
  end
end
