# Online Store Quick Check System - Implementation Plan

## Overview

This plan outlines the implementation of a system to quickly check for the presence of wishlisted records on configurable online record stores. The system will add an expandable section to record details pages with links to online stores, generated from user-configurable templates.

## Requirements Analysis

### Core Features

- **Expandable section on record details**: Collapsed by default, shows links to online stores
- **Configurable store templates**: User-managed templates stored in database
- **Template variables**: Support for record artist and title as search parameters
- **User management interface**: Dedicated section for managing store templates

### Example Use Case

Create a template for Amazon UK search: `https://www.amazon.co.uk/s?k={artist}+{title}+vinyl`
When viewing a record by "Pink Floyd" with title "The Wall", generate: `https://www.amazon.co.uk/s?k=Pink+Floyd+The+Wall+vinyl`

## Database Schema Design

### Online Store Templates Table

Following the application's established patterns:

```elixir
# Migration: create_online_store_templates.exs
defmodule MusicLibrary.Repo.Migrations.CreateOnlineStoreTemplates do
  use Ecto.Migration

  def change do
    create table(:online_store_templates, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :description, :text
      add :url_template, :text, null: false
      add :enabled, :boolean, default: true, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:online_store_templates, [:enabled])
  end
end
```

### Schema Module

```elixir
# lib/music_library/online_store_templates/online_store_template.ex
defmodule MusicLibrary.OnlineStoreTemplates.OnlineStoreTemplate do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "online_store_templates" do
    field :name, :string
    field :description, :string
    field :url_template, :string
    field :enabled, :boolean, default: true

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(template, attrs) do
    template
    |> cast(attrs, [:name, :description, :url_template, :enabled])
    |> validate_required([:name, :url_template])
    |> validate_length(:name, min: 1, max: 100)
    |> validate_length(:url_template, min: 1, max: 500)
    |> validate_url_template()
  end

  defp validate_url_template(changeset) do
    if template = get_field(changeset, :url_template) do
      case URI.parse(template) do
        %URI{scheme: scheme} when scheme in ["http", "https"] -> changeset
        _ -> add_error(changeset, :url_template, "must be a valid HTTP or HTTPS URL")
      end
    else
      changeset
    end
  end
end
```

### Context Module

```elixir
# lib/music_library/online_store_templates.ex
defmodule MusicLibrary.OnlineStoreTemplates do
  @moduledoc """
  The OnlineStoreTemplates context.
  """

  import Ecto.Query, warn: false
  alias MusicLibrary.Repo
  alias MusicLibrary.OnlineStoreTemplates.OnlineStoreTemplate

  @doc """
  Returns the list of enabled online store templates ordered by name.
  """
  def list_enabled_templates do
    OnlineStoreTemplate
    |> where([t], t.enabled == true)
    |> order_by([t], [asc: t.name])
    |> Repo.all()
  end

  @doc """
  Returns the list of all online store templates for management.
  """
  def list_templates do
    OnlineStoreTemplate
    |> order_by([t], [asc: t.name])
    |> Repo.all()
  end

  @doc """
  Gets a single online store template.
  """
  def get_template!(id), do: Repo.get!(OnlineStoreTemplate, id)

  @doc """
  Creates an online store template.
  """
  def create_template(attrs \\ %{}) do
    %OnlineStoreTemplate{}
    |> OnlineStoreTemplate.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates an online store template.
  """
  def update_template(%OnlineStoreTemplate{} = template, attrs) do
    template
    |> OnlineStoreTemplate.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes an online store template.
  """
  def delete_template(%OnlineStoreTemplate{} = template) do
    Repo.delete(template)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking online store template changes.
  """
  def change_template(%OnlineStoreTemplate{} = template, attrs \\ %{}) do
    OnlineStoreTemplate.changeset(template, attrs)
  end

  @doc """
  Generates a URL from a template by replacing variables with record data.
  """
  def generate_url(template, record) do
    artists_string = record.artists |> Enum.map(& &1.name) |> Enum.join(" ")

    template.url_template
    |> String.replace("{artist}", URI.encode(artists_string))
    |> String.replace("{title}", URI.encode(record.title))
  end
end
```

## User Interface Design

### Management Interface

Following the Scrobble Rules pattern for consistency:

#### Route Addition

```elixir
# lib/music_library_web/router.ex
# Add to the authenticated scope:
live "/online-store-templates", OnlineStoreTemplateLive.Index, :index
live "/online-store-templates/new", OnlineStoreTemplateLive.Index, :new
live "/online-store-templates/:id/edit", OnlineStoreTemplateLive.Index, :edit
```

#### Navigation Integration

```elixir
# lib/music_library_web/components/layouts/app.html.heex
# Add to the "More" dropdown menu:
<.dropdown_link href={~p"/online-store-templates"}>
  Online Store Templates
</.dropdown_link>
```

#### LiveView Index Page

```elixir
# lib/music_library_web/live/online_store_template_live/index.ex
defmodule MusicLibraryWeb.OnlineStoreTemplateLive.Index do
  use MusicLibraryWeb, :live_view

  alias MusicLibrary.OnlineStoreTemplates
  alias MusicLibrary.OnlineStoreTemplates.OnlineStoreTemplate

  @impl true
  def mount(_params, _session, socket) do
    {:ok, stream(socket, :templates, OnlineStoreTemplates.list_templates())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Online Store Template")
    |> assign(:template, OnlineStoreTemplates.get_template!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Online Store Template")
    |> assign(:template, %OnlineStoreTemplate{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Online Store Templates")
    |> assign(:template, nil)
  end

  @impl true
  def handle_info({MusicLibraryWeb.OnlineStoreTemplateLive.FormComponent, {:saved, template}}, socket) do
    {:noreply, stream_insert(socket, :templates, template)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    template = OnlineStoreTemplates.get_template!(id)
    {:ok, _} = OnlineStoreTemplates.delete_template(template)

    {:noreply, stream_delete(socket, :templates, template)}
  end

  @impl true
  def handle_event("toggle-enabled", %{"id" => id}, socket) do
    template = OnlineStoreTemplates.get_template!(id)
    {:ok, updated_template} = OnlineStoreTemplates.update_template(template, %{enabled: !template.enabled})

    {:noreply, stream_insert(socket, :templates, updated_template)}
  end
end
```

#### Template Design

```heex
<!-- lib/music_library_web/live/online_store_template_live/index.html.heex -->
<div class="px-4 py-6 sm:px-6 lg:px-8">
  <div class="sm:flex sm:items-center">
    <div class="sm:flex-auto">
      <h1 class="text-base font-semibold text-gray-900 dark:text-white">
        Online Store Templates
      </h1>
      <p class="mt-2 text-sm text-gray-700 dark:text-gray-300">
        Manage templates for generating links to online record stores.
      </p>
    </div>
    <div class="mt-4 sm:ml-16 sm:mt-0 sm:flex-none">
      <.button patch={~p"/online-store-templates/new"}>
        Add Template
      </.button>
    </div>
  </div>

  <div class="mt-8 flow-root">
    <div class="-mx-4 -my-2 overflow-x-auto sm:-mx-6 lg:-mx-8">
      <div class="inline-block min-w-full py-2 align-middle sm:px-6 lg:px-8">
        <ul role="list" class="divide-y divide-gray-200 dark:divide-gray-800" phx-update="stream" id="templates">
          <li
            :for={{id, template} <- @streams.templates}
            id={id}
            class="flex items-center justify-between gap-x-6 py-5"
          >
            <div class="min-w-0">
              <div class="flex items-start gap-x-3">
                <p class="text-sm font-semibold text-gray-900 dark:text-white">
                  <%= template.name %>
                </p>
                <.badge :if={template.enabled} color="success" size="sm">
                  Enabled
                </.badge>
                <.badge :if={!template.enabled} color="warning" size="sm">
                  Disabled
                </.badge>
              </div>
              <div class="mt-1 flex items-center gap-x-2 text-xs text-gray-500 dark:text-gray-400">
                <p class="truncate"><%= template.url_template %></p>
              </div>
              <p :if={template.description} class="mt-1 text-xs text-gray-500 dark:text-gray-400">
                <%= template.description %>
              </p>
            </div>
            <div class="flex flex-none items-center gap-x-4">
              <.button
                phx-click="toggle-enabled"
                phx-value-id={template.id}
                color={if template.enabled, do: "warning", else: "success"}
                variant="ghost"
                size="sm"
              >
                <%= if template.enabled, do: "Disable", else: "Enable" %>
              </.button>
              <.button
                patch={~p"/online-store-templates/#{template}/edit"}
                variant="ghost"
                size="sm"
              >
                Edit
              </.button>
              <.button
                phx-click={JS.push("delete", value: %{id: template.id})}
                data-confirm="Are you sure?"
                color="danger"
                variant="ghost"
                size="sm"
              >
                Delete
              </.button>
            </div>
          </li>
        </ul>
      </div>
    </div>
  </div>
</div>

<.modal :if={@live_action in [:new, :edit]} id="template-modal" show on_cancel={JS.patch(~p"/online-store-templates")}>
  <.live_component
    module={MusicLibraryWeb.OnlineStoreTemplateLive.FormComponent}
    id={@template.id || :new}
    title={@page_title}
    action={@live_action}
    template={@template}
    patch={~p"/online-store-templates"}
  />
</.modal>
```

### Record Details Integration

Add to the wishlist show page template:

```heex
<!-- lib/music_library_web/live/wishlist_live/show.html.heex -->
<!-- Add this section after the existing record details -->

<div class="mt-8">
  <details class="px-4 text-zinc-700 hover:text-zinc-500 dark:text-zinc-400 dark:hover:text-zinc-300">
    <summary class="text-sm font-medium cursor-pointer">
      Check Online Stores
    </summary>
    <div class="mt-4 space-y-2">
      <div
        :for={template <- @online_store_templates}
        class="flex items-center justify-between py-2 px-3 bg-gray-50 dark:bg-gray-800 rounded-lg"
      >
        <span class="text-sm font-medium text-gray-900 dark:text-white">
          <%= template.name %>
        </span>
        <.button
          href={OnlineStoreTemplates.generate_url(template, @record)}
          target="_blank"
          rel="noopener noreferrer"
          variant="ghost"
          size="sm"
          class="ml-2"
        >
          <.icon name="hero-arrow-top-right-on-square" class="h-4 w-4" />
          Search
        </.button>
      </div>
    </div>
  </details>
</div>
```

### LiveView Updates

Update the wishlist show LiveView to load templates:

```elixir
# lib/music_library_web/live/wishlist_live/show.ex
# Add to the mount function:
online_store_templates = MusicLibrary.OnlineStoreTemplates.list_enabled_templates()

socket =
  socket
  |> assign(:record, record)
  |> assign(:online_store_templates, online_store_templates)
  |> assign(:page_title, record.title)
```

## Implementation Steps

### Phase 1: Database Foundation

1. Create migration for `online_store_templates` table
2. Create schema module with validation
3. Create context module with CRUD operations
4. Run migration and test basic functionality

### Phase 2: Management Interface

1. Create LiveView modules for template management
2. Create form component for template editing
3. Add routes to router
4. Add navigation link to main layout
5. Style templates using existing design patterns

### Phase 3: Record Details Integration

1. Update wishlist show LiveView to load templates
2. Add expandable section to show template
3. Implement URL generation logic
4. Test template variable replacement

### Phase 4: Testing & Refinement

1. Add comprehensive tests for context functions
2. Add LiveView tests for management interface
3. Test URL generation with various record data
4. Validate template functionality end-to-end

## Security Considerations

### URL Template Validation

- Validate URL templates contain only HTTP/HTTPS schemes
- Sanitize user input in templates
- Encode record data properly when generating URLs

### Access Control

- Templates management requires authentication
- Template visibility follows existing permission patterns

## Testing Strategy

### Unit Tests

- Context module functions (CRUD operations)
- URL generation with various record data
- Template validation logic

### Integration Tests

- LiveView template management workflow
- Template display on record details pages
- URL generation end-to-end

### Example Test Cases

```elixir
defmodule MusicLibrary.OnlineStoreTemplatesTest do
  use MusicLibrary.DataCase

  alias MusicLibrary.OnlineStoreTemplates

  describe "generate_url/2" do
    test "replaces artist and title variables correctly" do
      template = %OnlineStoreTemplate{
        url_template: "https://example.com/search?q={artist}+{title}"
      }

      record = %Record{
        title: "Dark Side of the Moon",
        artists: [%Artist{name: "Pink Floyd"}]
      }

      assert OnlineStoreTemplates.generate_url(template, record) ==
               "https://example.com/search?q=Pink+Floyd+Dark+Side+of+the+Moon"
    end
  end
end
```

## Database Migration Commands

```bash
# Create migration
mix ecto.gen.migration create_online_store_templates

# Run migration
mix ecto.migrate

# Rollback if needed
mix ecto.rollback
```

## Default Template Examples

Consider seeding the database with common store templates:

```elixir
# priv/repo/seeds.exs additions
alias MusicLibrary.OnlineStoreTemplates

templates = [
  %{
    name: "Amazon UK",
    description: "Search Amazon UK for vinyl records",
    url_template: "https://www.amazon.co.uk/s?k={artist}+{title}+vinyl&i=popular"
  },
  %{
    name: "Discogs",
    description: "Search Discogs marketplace",
    url_template: "https://www.discogs.com/search/?q={artist}+{title}&type=all"
  },
  %{
    name: "eBay",
    description: "Search eBay for records",
    url_template: "https://www.ebay.co.uk/sch/i.html?_nkw={artist}+{title}+vinyl"
  }
]

Enum.each(templates, &OnlineStoreTemplates.create_template/1)
```

## Conclusion

This implementation provides a clean, maintainable system for checking online stores that:

- Follows existing application patterns and conventions
- Provides a user-friendly management interface
- Integrates seamlessly with the existing record details pages
- Supports extensibility for future enhancements
- Maintains security and validation standards

The system is designed to be conservative, focusing on core functionality while following the established UI and database patterns throughout the application.

