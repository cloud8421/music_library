defmodule MusicLibraryWeb.ScrobbleRulesLive.FormComponent do
  use MusicLibraryWeb, :live_component

  alias MusicLibrary.ScrobbleRules

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <header class="mb-6">
        <h1 class="text-lg font-semibold text-zinc-900 dark:text-zinc-100">
          {@title}
        </h1>
      </header>

      <.simple_form
        for={@form}
        id="scrobble_rule-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.select
          field={@form[:type]}
          label={gettext("Rule Type")}
          options={[
            {gettext("Album"), "album"},
            {gettext("Artist"), "artist"}
          ]}
          placeholder={gettext("Select a rule type")}
        />

        <.input
          field={@form[:match_value]}
          type="text"
          label={match_value_label(@form[:type].value)}
          placeholder={match_value_placeholder(@form[:type].value)}
        />

        <.input
          field={@form[:target_musicbrainz_id]}
          type="text"
          label={gettext("Target MusicBrainz ID")}
          placeholder="e.g. 12345678-1234-1234-1234-123456789012"
          class="font-mono"
        />

        <.textarea
          field={@form[:description]}
          label={gettext("Description (optional)")}
          placeholder={gettext("Add a description to help identify this rule")}
        />

        <.switch field={@form[:enabled]} label={gettext("Enable this rule")} />

        <:actions>
          <.button phx-disable-with={gettext("Saving...")}>
            {gettext("Save Rule")}
          </.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{scrobble_rule: scrobble_rule} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:form, fn ->
       to_form(ScrobbleRules.change_scrobble_rule(scrobble_rule))
     end)}
  end

  @impl true
  def handle_event("validate", %{"scrobble_rule" => scrobble_rule_params}, socket) do
    changeset =
      ScrobbleRules.change_scrobble_rule(socket.assigns.scrobble_rule, scrobble_rule_params)

    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"scrobble_rule" => scrobble_rule_params}, socket) do
    save_scrobble_rule(socket, socket.assigns.action, scrobble_rule_params)
  end

  defp save_scrobble_rule(socket, :edit, scrobble_rule_params) do
    case ScrobbleRules.update_scrobble_rule(socket.assigns.scrobble_rule, scrobble_rule_params) do
      {:ok, scrobble_rule} ->
        notify_parent({:saved, scrobble_rule})

        {:noreply,
         socket
         |> put_flash(:info, gettext("Scrobble rule updated successfully"))
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_scrobble_rule(socket, :new, scrobble_rule_params) do
    case ScrobbleRules.create_scrobble_rule(scrobble_rule_params) do
      {:ok, scrobble_rule} ->
        notify_parent({:saved, scrobble_rule})

        {:noreply,
         socket
         |> put_flash(:info, gettext("Scrobble rule created successfully"))
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp match_value_label(type) do
    case type do
      "album" -> gettext("Album Title")
      "artist" -> gettext("Artist Name")
      _ -> gettext("Match Value")
    end
  end

  defp match_value_placeholder(type) do
    case type do
      "album" -> gettext("e.g. The Dark Side of the Moon")
      "artist" -> gettext("e.g. Pink Floyd")
      _ -> gettext("Enter the value to match")
    end
  end
end
